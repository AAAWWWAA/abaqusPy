      subroutine return_mapping(spr,phi_n,eeq_n,dphi_n,voce_params,
     $     dstran,stran,stran_el)
c     spr    : predictor stress at k=0
c     eeq_n  : accumulative plastic equivalent strain at step n
c     dphi_n : dphi at step n
c     voce_params (quite self-explanatory)
c     dstran : total incremental strain given between steps n and n+1
c     stran  : total cumulative strain at step n

      implicit none
      integer ntens
      dimension spr(ntens), dphi_n(ntens),sn1(ntens),s_k(ntens),
     $     spr_k(0:mxnr,ntens),dstran(ntens),stran(ntens),
     $     stran_el(ntens),dstran_el(ntens),dstran_el_k(ntens),
     $     aux_n(ntens),em_k(ntens)
      real*8 spr,dphi_n,dstran,stran,strain_el,dstran_el,dstran_el_k
      real*8 sn1                ! stress at step (n+1) - to be determined
      real*8 s_k,seq_k,spr_k    ! eq stress at nr-step k, stress predic at nr-step k
      real*8 enorm_k(mxnr,ntens) ! m_(n+alpha)
      real*8 fo(mxnr),fp(mxnr)  ! Fobjective, Jacobian for NR
      real*8 dlamb_k(mxnr),phi_n
      real*8 dphi_k(ntens),d2phi_k(ntens,ntens)
      real*8 delta_eeq,eeq_n,eeq_k(mxnr)
      real*8 voce_params(4),h_flow,dh,phi_k,phi_ks(mxnr),em_k,tolerance
      parameter(tolerance=1d-10)

      delta_eeq = 0.
      spr_k(1,:) = spr(:)       !! stress predictor
      enorm_k(1,:) = dphi_n(:)
      phi_ks(1) = phi_n

c     iv. return mapping (loop over k)
      k=1
      do while (fo(k)<tolerance)
         s_k(:) = spr_k(k,:)    !! predictor stress at current k
         em_k(:) = enorm_k(k,:) !! yield normal at current k
         eeq_k = eeq_n + delta_eeq !! assumed plastic strain at current k
         phi_k = phi_ks(k)

         call voce(eeq,voce_params(1),voce_params(2),voce_params(3),
     $        voce_params(1),h_flow,dh)
c             f   = yield - hardening             (objective function)
         fo(k) = phi_ks(k) - h_flow
         call calc_fp(dphi_k,Cel,dh,fp(k))
c         2.  Update the multiplier^(k+1)  (dlamb)
c             dlamb^(k+1) = dlamb^k - f/fp
         dlamb_k = dlamb_k - fo/fp(k)
c             find the new predictor stress for next NR step
c                Using  dE = dE^(el)^(k+1) + dlamb^(k+1),
c                Update dE^(el)^(k+1) and update the predictor stress.
         dstran_el(:) = dstran(:) - dlamb_k
         call add_array(stran_el_k,dstran_el,ntens)
c             s_(n+1)^(k+1) = C^e dE^(el)
         call mult_array(cel,stran_el_k,aux_n)
         spr_k(k+1,:) = aux_n(:)
c$$$c         3. Find normal of current predictor stress (s_(n+1)^k)
c$$$c             save the normal to m_(n+alpha)
         call vm_shell(spr_k(k+1,:),enorm_k(k+1,:),dphi_k,d2phi_k)
         k=k+1
         if (k.ge.mxnr) then
            write(*,*) 'Could not converge in NR scheme'
            stop
         endif
      enddo

      end subroutine


c-----------------------------------------------------------------------
c     Calculate fp using the below formula
c     fp  = r(s^eq_(n+1)^k)/r(s_(n+1)^k) : -C^el : r(s^eq_(n+1)^k / r(s_(n+1)^k) + H`)
c     fp = dphi_i C_ij dphi_j + H
      subroutine calc_fp(dphi,Cel,dh,ntens,fp)
c     intent(in) dphi,Cel,dh,ntens
c     intent(out) fp
      integer ntens
      dimension s(ntens),Cel(ntens,ntens),dphi(ntens)
      real*8 s,seq,Cel,dphi
      fp=0.d0
      do 10 i=1,ntens
      do 10 j=1,ntens
         fp=fp+dphi(i) * Cel(i,j) * dphi(j) +dh
 10   continue
      return
      end subroutine
