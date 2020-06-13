!
! Copyright (C) 2001-2012 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
! A small utility that reads the first q from a dynamical matrix file (either xml or plain text),
! recomputes the system symmetry (starting from the lattice) and generates the star of q.
!
! Useful for debugging and for producing the star of the wannier-phonon code output.
!
! Syntax:
!   q2qstar.x filein [fileout]
!
! fileout default: rot_filein (old format) or rot_filein.xml (new format)
!
!----------------------------------------------------------------------------
PROGRAM make_wedge
  !----------------------------------------------------------------------------
  !
  USE kinds,              ONLY : DP
  USE constants,          ONLY : amu_ry
  USE parameters,         ONLY : ntypx
  USE mp,                 ONLY : mp_bcast
  USE mp_global,          ONLY : mp_startup, mp_global_end
  USE mp_world,           ONLY : world_comm
  USE io_global,          ONLY : ionode_id, ionode, stdout
  USE environment,        ONLY : environment_start, environment_end
  ! symmetry
  USE symm_base,          ONLY : s, invs, nsym, find_sym, set_sym_bl, irt, copy_sym, nrot, inverse_s, t_rev
  ! for reading the dyn.mat.
  USE cell_base,          ONLY : at, bg, celldm, ibrav, omega
  USE ions_base,          ONLY : nat, ityp, ntyp => nsp, atm, tau, amass
  ! as above, unused here
  USE control_ph,         ONLY : xmldyn
  USE noncollin_module,   ONLY : m_loc, nspin_mag
  !
  USE dynmat,             ONLY : w2
  !
  ! for non-xml file only:
  USE dynamicalq,         ONLY : dq_phiq => phiq, dq_tau => tau, dq_ityp => ityp, zeu 
  ! fox xml files only
  USE io_dyn_mat,         ONLY : read_dyn_mat_param, read_dyn_mat_header, &
                                 read_dyn_mat, read_dyn_mat_tail, &
                                 write_dyn_mat_header
  ! small group symmetry
  USE lr_symm_base,       ONLY : rtau, nsymq, minus_q, irotmq, gi, gimq, invsymq
  USE control_lr,         ONLY : lgamma
  USE decompose_d2
  USE input_fc,         ONLY : forceconst2_grid, ph_system_info
  USE input_fc, ONLY : read_system, aux_system
  !
  IMPLICIT NONE
  !
  CHARACTER(len=7),PARAMETER :: CODE="MKWEDGE"
  CHARACTER(len=256) :: fildyn, filout
  INTEGER :: ierr, nargs
  !
  INTEGER       :: nq1, nq2, nq3, nqmax, nqs, isq (48), imq, nqq
  REAL(DP),ALLOCATABLE      :: x_q(:,:), w_q(:)
  REAL(DP) :: xq(3), sxq(3,49)
  !
  LOGICAL :: sym(48), lrigid, skip_equivalence, time_reversal
  !
  COMPLEX(DP),ALLOCATABLE :: phi(:,:,:,:), d2(:,:), basis(:,:,:)
  REAL(DP),ALLOCATABLE :: decomposition(:)
  INTEGER :: i,j, icar,jcar, na,nb, rank, iq
  TYPE(ph_system_info) :: Sinfo
  !
  CALL mp_startup()
  CALL environment_start(CODE)
  !
  ! set up output
  IF (nargs > 1) THEN
    CALL get_command_argument(2, filout)
  ELSE
      filout = "rot_"//TRIM(fildyn)
  ENDIF
  !
  ! Read system info from a mat2R file
  OPEN(unit=999,file="mat2R",action='READ',status='OLD')
  CALL read_system(999, Sinfo)
  CALL aux_system(Sinfo)
  CLOSE(999)
  ! Quantum-ESPRESSO symmetry subroutines use the global variables
  ! we copy the system data from structure S
  ntyp   = Sinfo%ntyp
  nat    = Sinfo%nat
  ALLOCATE(tau(3,nat))
  ALLOCATE(ityp(nat))
  celldm = Sinfo%celldm
  at     = Sinfo%at
  bg     = Sinfo%bg
  omega  = Sinfo%omega
  atm(1:ntyp)    = Sinfo%atm(1:ntyp)
  amass(1:ntyp)  = Sinfo%amass(1:ntyp)
  tau(:,1:nat)   = Sinfo%tau(:,1:nat)
  ityp(1:nat)    = Sinfo%ityp(1:nat)
  !CALL latgen(ibrav,celldm,at(1,1),at(1,2),at(1,3),omega)
  !at = at / celldm(1)  !  bring at in units of alat
  !CALL volume(celldm(1),at(1,1),at(1,2),at(1,3),omega)
  !CALL recips(at(1,1),at(1,2),at(1,3),bg(1,1),bg(1,2),bg(1,3))
  !
  ! ######################### symmetry setup #########################
  ! ~~~~~~~~ setup bravais lattice symmetry ~~~~~~~~ 
  CALL set_sym_bl ( )
  WRITE(stdout, '(5x,a,i3)') "Symmetries of bravais lattice: ", nrot
  !
  ! ~~~~~~~~ setup crystal symmetry ~~~~~~~~ 
  IF(.not.allocated(m_loc))  THEN
    ALLOCATE(m_loc(3,nat))
    m_loc = 0._dp
  ENDIF
  
  CALL find_sym ( nat, tau, ityp, .false., m_loc )
  WRITE(stdout, '(5x,a,i3)') "Symmetries of crystal:         ", nsym
  !
  ! Find the reduced grid of q-points:
  skip_equivalence = .FALSE.
  time_reversal    = .true.
  nq1 = 2
  nq2 = 2
  nq3 = 2
  nqmax = nq1*nq2*nq3
  ALLOCATE(x_q(3,nqmax), w_q(nqmax))
  call kpoint_grid( nsym, time_reversal, skip_equivalence, s, t_rev, bg, nqmax,&
                    0,0,0, nq1,nq2,nq3, nqs, x_q, w_q )
  !
  WRITE(stdout, *) "Generated ", nqs, "points"

  ALLOCATE(rtau( 3, 48, nat), d2(3*nat,3*nat))
  Q_POINTS_LOOP : &
  DO iq = 1, nqs
    WRITE(stdout, *) "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["
    WRITE(stdout, '(3f12.4)') x_q(:,iq)


  ! ~~~~~~~~ setup small group of q symmetry ~~~~~~~~ 
  ! part 1: call smallg_q and the copy_sym, 
  xq = x_q(:,iq)
  minus_q = .true.

  sym = .false.
  sym(1:nsym) = .true.
  CALL smallg_q(xq, 0, at, bg, nsym, s, sym, minus_q)
  nsymq = copy_sym(nsym, sym)
  ! recompute the inverses as the order of sym.ops. has changed
  CALL inverse_s ( ) 



  ! part 2: this computes gi, gimq
  call set_giq (xq,s,nsymq,nsym,irotmq,minus_q,gi,gimq)
  WRITE(stdout, '(5x,a,i3)') "Symmetries of small group of q:", nsymq
  IF(minus_q) WRITE(stdout, '(10x,a)') "in addition sym. q -> -q+G:"
  !
  ! finally this does some of the above again and also computes rtau...
  CALL sgam_lr(at, bg, nsym, s, irt, tau, rtau, nat)
  !
  ! the next subroutine uses symmetry from global variables
  CALL find_d2_symm_base(xq, rank, basis)
  !
  DO i = 1, rank
    d2 = basis(:,:,i)
    WRITE(100*iq+i,*) i, xq
    CALL star_q(xq, at, bg, nsym, s, invs, nqs, sxq, isq, imq, .true. )
    ! Generate the star of q and write it on file (i actually want to have it in a variable!)
    CALL q2qstar_ph (d2, at, bg, nat, nsym, s, invs, irt, rtau, &
                     nqs, sxq, isq, imq, 100*iq+i)
  ENDDO

  !ALLOCATE(d2(3*nat,3*nat), w2(3*nat), decomposition(rank))
  !CALL compact_dyn(nat, d2, phi)
  !  print*, d2
  !print*, "== DECOMPOSITION =="
  !DO i = 1,rank
  !  decomposition(i) = dotprodmat(3*nat,d2, basis(:,:,i))
  !  print*, i, decomposition(i)
  !ENDDO
  !
  !d2 = 0
  !DO i = 1,rank
  !  d2 = d2 + decomposition(i)*basis(:,:,i)
  !ENDDO

  ENDDO Q_POINTS_LOOP
  ! print*, d2

  !DEALLOCATE(phi, d2, w2)
  !DEALLOCATE(rtau, tau, ityp)
  !DEALLOCATE(irt) ! from symm_base
  !----------------------------------------------------------------------------
 END PROGRAM make_wedge
!----------------------------------------------------------------------------
!
