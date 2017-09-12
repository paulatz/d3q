MODULE overlap
  !
  USE kinds, ONLY : DP
  TYPE :: order_type
    COMPLEX(DP),ALLOCATABLE,PRIVATE :: e_prev(:,:)
    INTEGER,ALLOCATABLE     :: idx(:)
    CONTAINS
      PROCEDURE :: set => set_idx
      PROCEDURE :: set_path => set_path_idx
      PROCEDURE :: reset => reset_idx
  END TYPE
  !

  CONTAINS
  !
  SUBROUTINE reset_idx(self)
    IMPLICIT NONE
    CLASS(order_type),INTENT(inout) :: self
    DEALLOCATE(self%idx, self%e_prev)
    RETURN
  END SUBROUTINE
  
  ! Specialized version of set_idx, that aso checks the path length:
  ! if the path length at this point is the same than at the previous point,
  ! it means that there is a discontinuity, do not attempt to compute the overlap
  ! just keep the current order
  ! Same story when the length is reset to zero
  SUBROUTINE set_path_idx(self, nat3, w, e, iq, nq, lpath) !RESULT(order_out)
    USE constants, ONLY : RY_TO_CMM1
    !USE merge_degenerate, ONLY : merge_degen
    IMPLICIT NONE
    CLASS(order_type),INTENT(inout) :: self
    !
    INTEGER,INTENT(in) :: nat3
    REAL(DP),INTENT(in) :: w(nat3)
    COMPLEX(DP),INTENT(in) :: e(nat3,nat3)
    !
    INTEGER,INTENT(in) :: iq,nq
    REAL(DP) ::  lpath(nq)
    INTEGER :: i
    !
    IF(iq>1 .and. ALLOCATED(self%e_prev))THEN
      IF(lpath(iq-1)==lpath(iq) .or. lpath(iq)==0._dp) THEN
        DO i = 1, nat3
          self%e_prev(:,i) = e(:,self%idx(i))
        ENDDO
        ! quick return
        RETURN
      ENDIF
    ENDIF
    !
    ! otherwise, do the full overlap analysis:
    CALL set_idx(self, nat3, w, e) 
    !
  END SUBROUTINE
  !
  SUBROUTINE set_idx(self, nat3, w, e)
    USE constants, ONLY : RY_TO_CMM1
    !USE merge_degenerate, ONLY : merge_degen
    IMPLICIT NONE
    CLASS(order_type),INTENT(inout) :: self
    !
    INTEGER,INTENT(in) :: nat3
    REAL(DP),INTENT(in) :: w(nat3)
    COMPLEX(DP),INTENT(in) :: e(nat3,nat3)
    !INTEGER :: order_out(nat3)
    !
    COMPLEX(DP) :: e_new(nat3,nat3)
    !
    REAL(DP)   :: olap
    COMPLEX(DP) :: dolap
    REAL(DP)   :: maxx
    INTEGER    :: i,j,j_,jmax, orderx(nat3)
    LOGICAL    :: assigned(nat3)
    REAL(DP),PARAMETER :: olap_thr = 0._dp
    REAL(DP),PARAMETER :: w_thr = 10000._dp/RY_TO_CMM1
    REAL(DP),PARAMETER :: eps = 0._dp
    !
    ! On first call, order is just 1..3*nat, then quick return
    IF(.not.ALLOCATED(self%e_prev))THEN
      ALLOCATE(self%e_prev(nat3,nat3))
      self%e_prev = e
      ALLOCATE(self%idx(nat3))
      FORALL(i=1:nat3) self%idx(i) = i
      !order_out = order
      RETURN
    ELSE
      IF(size(self%e_prev,1)/=nat3) CALL errore("overlap","inconsistent nat3",1)
    ENDIF
    !
    e_new = e
    !CALL merge_degen(nat3, nat3, e_new, w)
    !
    assigned = .false.
    !WRITE(*,'(99i2)') order
    DO i = 1,nat3
      maxx = -1._dp
      jmax = -1
      DO j_ = 1,nat3
        j = self%idx(j_)
        IF(assigned(j)) CYCLE
        ! Square modulus:
        dolap = SUM( self%e_prev(:,i)*DCONJG(e_new(:,j)) )
        olap = DBLE(dolap*DCONJG(dolap))
        ! Do not change the order if the overlap condition is weak
        ! i.e. where some modes are degenerate, or if points are too far apart
        IF(olap>(maxx+eps) .and.olap>olap_thr .and. ABS(w(i)-w(j))<w_thr )THEN
        !IF(olap>(maxx+eps) .and.olap>olap_thr )THEN
          jmax = j
          maxx = olap
        ENDIF
        !
      ENDDO
      !
      IF(jmax<0) THEN
        IF (assigned(i)) CALL errore("overlap_sort","dont know what to do",1)
        jmax = i
      ENDIF
      !
      !IF(i/=jmax) print*, i, "->", jmax, maxx
      ! Destroy polarizations already assigned:
      !e_new(:,jmax) = 0._dp
      self%e_prev(:,i) = e_new(:,jmax)
      assigned(jmax) = .true.
      orderx(i) = jmax !order(jmax)
    ENDDO
    !
    ! Prepare for next call
    !self%e_prev = e
    self%idx = orderx
    !
    ! Set output
    !order_out = orderx
    !
  END SUBROUTINE
  !  
END MODULE