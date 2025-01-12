# Makefile for ballistic conductance (D3Q)

include ../../make.inc

STRIP = true

# location of needed modules
MODFLAGS= $(MOD_FLAG)../../Modules $(MOD_FLAG)../../XClib $(MOD_FLAG)../../LAXlib $(MOD_FLAG)../../UtilXlib \
          $(MOD_FLAG)../../FFTXlib $(MOD_FLAG)../../PW/src $(MOD_FLAG)../../LR_Modules $(MOD_FLAG)../../PHonon/PH \
	  $(MOD_FLAG)../../upflib $(MOD_FLAG).

D3QOBJS = d3q.o

D3QLIBS = \
allocate_d3.o \
cmdline_param.o \
d2mxc.o \
d3_basis.o \
d3com.o \
d3_debug.o \
d3_exc.o \
d3_exc_gc.o \
d3_grid.o \
d3_h_psi.o \
d3_init.o \
d3_iofiles.o \
d3ionq.o \
d3matrix.o \
d3matrix_io2.o \
d3_nlcc.o \
d3_open.o \
d3_readin.o \
d3_recover.o \
d3_reset.o \
d3_restart.o \
d3_setup.o \
d3_shuffle.o \
d3_symmetry.o \
d3_valence.o \
dpsi1dpsi2dv3.o \
dpsi1dv2dpsi3.o \
dq1rhodq23v.o \
dq_vscf.o \
drho_add_phase.o \
dvdpsi.o \
efermi_shift.o \
gen_dpdvp.o \
h_psiq.o \
incdrhoscf2.o \
print_clock_d3.o \
qstar_d3.o \
rhodq123v.o \
rotate_d3.o \
run_nscf_d3.o \
set_kplus3q.o \
setup_d3gc.o \
solve_linter_d3q.o \
stop_d3.o \
w_1gauss.o \
write_d3dyn.o 

PHOBJS = ../../PHonon/PH/libph.a ../../PHonon/PH/libphaux.a
LRMODS = ../../LR_Modules/liblrmod.a
PWOBJS = ../../PW/src/libpw.a
QEMODS = ../../Modules/libqemod.a ../../KS_Solvers/libks_solvers.a ../../KS_Solvers/CG/libcg.a \
         ../../FFTXlib/libqefft.a ../../LAXlib/libqela.a ../../UtilXlib/libutil.a \
	 ../../dft-d3/libdftd3qe.a ../../upflib/libupf.a ../../XClib/xc_lib.a

LIBOBJS = ../../clib/clib.a 


TLDEPS= bindir mods libs pw ph

all : tldeps d3q.x

d3q.x : libd3q.a $(D3QOBJS) $(PWOBJS) $(PHOBJS) $(QEMODS) $(LIBOBJS)
	$(LD) $(LDFLAGS) -o d3q.x $(D3QOBJS) $(D3QLIBS) \
		libd3q.a $(PHOBJS) $(LRMODS) $(PWOBJS) $(QEMODS) $(LIBOBJS) $(QELIBS)
	$(STRIP) $@
	- ( cd ../../bin ; ln -fs ../D3Q/src/d3q.x . )

d3q-libs : libd3q.a

libd3q.a : $(D3QLIBS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

tldeps:
	test -n "$(TLDEPS)" && ( cd ../.. ; $(MAKE) $(MFLAGS) $(TLDEPS) || exit 1) || :
 
clean :
	- /bin/rm -f *.x *.o *~ *.F90 *.d *.mod *.i *.a *.L
	- /bin/rm -f ../../bin/d3q.x

include make.depend

