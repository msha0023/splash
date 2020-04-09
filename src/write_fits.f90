!-----------------------------------------------------------------
!
!  This file is (or was) part of SPLASH, a visualisation tool
!  for Smoothed Particle Hydrodynamics written by Daniel Price:
!
!  http://users.monash.edu.au/~dprice/splash
!
!  SPLASH comes with ABSOLUTELY NO WARRANTY.
!  This is free software; and you are welcome to redistribute
!  it under the terms of the GNU General Public License
!  (see LICENSE file for details) and the provision that
!  this notice remains intact. If you modify this file, please
!  note section 2a) of the GPLv2 states that:
!
!  a) You must cause the modified files to carry prominent notices
!     stating that you changed the files and the date of any change.
!
!  Copyright (C) 2020- Daniel Price. All rights reserved.
!  Contact: daniel.price@monash.edu
!
!-----------------------------------------------------------------
!----------------------------------------------------------------------
!
!  Module handling read and write of FITS files
!  With thanks to Christophe Pinte
!
!----------------------------------------------------------------------
module readwrite_fits
 implicit none
 public :: read_fits_image,write_fits_image,fits_error
 public :: read_fits_cube,write_fits_cube
 public :: read_fits_header
 public :: get_floats_from_fits_header

 private

contains

!---------------------------------------------------
! subroutine to read image from FITS file
! using cfitsio library
!---------------------------------------------------
subroutine read_fits_image(filename,image,naxes,ierr,hdr)
 character(len=*), intent(in)   :: filename
 real, intent(out), allocatable :: image(:,:)
 character(len=:), intent(inout), allocatable, optional :: hdr(:)
 integer, intent(out) :: naxes(2),ierr
 integer :: iunit,ireadwrite,npixels,blocksize
 integer :: firstpix,nullval,group,nfound
 logical :: anynull
 !
 !--open file and read header information
 !
 ierr = 0
 call ftgiou(iunit,ierr)

 ireadwrite = 0
 call ftopen(iunit,filename,ireadwrite,blocksize,ierr)

 if (ierr /= 0) then
    ierr = -1
    return
 endif
 !
 !--read fits header (this is optional)
 !
 if (present(hdr)) call read_fits_head(iunit,hdr,ierr)
 !
 !--get the essential things from the header
 !
 call ftgknj(iunit,'NAXIS',1,2,naxes,nfound,ierr)
 npixels = naxes(1)*naxes(2)
 !
 !--sanity check the header read
 !
 if (npixels <= 0) then
    !print*,' ERROR: No pixels found'
    ierr = 1
    return
 endif
 !
 ! read image
 !
 firstpix = 1
 nullval = -999
 group = 1
 allocate(image(naxes(1),naxes(2)),stat=ierr)
 if (ierr /= 0) then
    ierr = 2
    return
 endif
 ierr = 0
 call ftgpve(iunit,group,firstpix,npixels,nullval,image,anynull,ierr)
 call ftclos(iunit,ierr)
 call ftfiou(iunit,ierr)

end subroutine read_fits_image

!---------------------------------------------------
! read FITS header from file
!---------------------------------------------------
subroutine read_fits_header(filename,hdr,ierr)
 character, intent(in)  :: filename
 character(len=:), allocatable, intent(out) :: hdr(:)
 integer, intent(out) :: ierr
 integer :: ireadwrite,iunit,blocksize

 ierr = 0
 call ftgiou(iunit,ierr)

 ireadwrite = 0
 call ftopen(iunit,filename,ireadwrite,blocksize,ierr)
 if (ierr /= 0) return
 !
 !--read fits header (this is optional)
 !
 call read_fits_head(iunit,hdr,ierr)
 call ftclos(iunit,ierr)
 call ftfiou(iunit,ierr)
   
end subroutine read_fits_header

!---------------------------------------------------
! internal subroutine to read FITS header information
!---------------------------------------------------
subroutine read_fits_head(iunit,hdr,ierr)
 integer, intent(in)  :: iunit
 integer, intent(out) :: ierr
 character(len=:), allocatable, intent(inout) :: hdr(:)
 character(len=80) :: record
 integer :: i,nkeys,nspace

! The FTGHSP subroutine returns the number of existing keywords in the
! current header data unit (CHDU), not counting the required END keyword,
 call ftghsp(iunit,nkeys,nspace,ierr)
 !
 ! allocate memory
 !
 if (allocated(hdr)) deallocate(hdr)
 allocate(character(80) :: hdr(nkeys))

! Read each 80-character keyword record, and print it out.
 do i = 1, nkeys
    call ftgrec(iunit,i,record,ierr)
    hdr(i) = record
    !print *,hdr(i)
 end do

end subroutine read_fits_head

!---------------------------------------------------
! internal subroutine to write FITS header information
! excluding things we have changed
!---------------------------------------------------
subroutine write_fits_head(iunit,hdr,ierr)
 integer, intent(in) :: iunit
 character(len=80), intent(in) :: hdr(:)
 integer, intent(out) :: ierr
 integer :: i,morekeys

 ierr = 0
 morekeys = size(hdr)
 call fthdef(iunit,morekeys,ierr)
 do i=1,size(hdr)
    select case(hdr(i)(1:6))
    case('SIMPLE','BITPIX','NAXIS ','NAXIS1','NAXIS2','NAXIS3','NAXIS4','EXTEND')
       ! skip the above keywords
    case default
       call ftprec(iunit,hdr(i),ierr)
    end select
 enddo

end subroutine write_fits_head

!---------------------------------------------------
! subroutine to read spectral cube from FITS file
! using cfitsio library
!---------------------------------------------------
subroutine read_fits_cube(filename,image,naxes,ierr,hdr)
 character(len=*), intent(in)   :: filename
 real, intent(out), allocatable :: image(:,:,:)
 character(len=:), intent(inout), allocatable, optional :: hdr(:)
 integer, intent(out) :: naxes(4),ierr
 integer :: iunit,ireadwrite,npixels,blocksize
 integer :: firstpix,nullval,group
 logical :: anynull
 integer :: ndim
 !
 !--open file and read header information
 !
 ierr = 0
 call ftgiou(iunit,ierr)

 ireadwrite = 0
 call ftopen(iunit,filename,ireadwrite,blocksize,ierr)
 if (ierr /= 0) then
    ierr = -1
    return
 endif

 if (present(hdr)) call read_fits_head(iunit,hdr,ierr)

 call ftgidm(iunit,ndim,ierr) ! get_img_dim
 call ftgisz(iunit,3,naxes(1:ndim),ierr)
 if (ndim==2) naxes(3) = 1
 if (ndim>=3) ndim = 3
 ! call ftgknj(iunit,'NAXIS',1,2,naxes,nfound,ierr)
 npixels = product(naxes(1:ndim))
 !
 ! sanity check the header read
 !
 if (npixels <= 0) then
    ierr = 1
    return
 endif
 !
 ! read images
 !
 firstpix = 1
 nullval = -999
 group = 1
 allocate(image(naxes(1),naxes(2),naxes(3)),stat=ierr)
 if (ierr /= 0) then
    ierr = 2
    return
 endif
 ierr = 0
 call ftgpve(iunit,group,firstpix,npixels,nullval,image,anynull,ierr)
 call ftclos(iunit,ierr)
 call ftfiou(iunit,ierr)
  
end subroutine read_fits_cube

!---------------------------------------------------
! error code handling
!---------------------------------------------------
 character(len=30) function fits_error(ierr)
  integer, intent(in) :: ierr

  select case(ierr)
  case(2)
     fits_error = 'could not allocate memory'
  case(1)
     fits_error = 'no pixels found'
  case(-1)
     fits_error = 'could not open fits file'
  case default
     fits_error = 'unknown error'
  end select

 end function fits_error

!------------------------------------------------
! Writing new fits file
!------------------------------------------------
 subroutine write_fits_image(filename,image,naxes,ierr,hdr)
  character(len=*), intent(in) :: filename
  integer, intent(in)  :: naxes(2)
  real(kind=4),     intent(in) :: image(naxes(1),naxes(2))
  integer, intent(out) :: ierr
  character(len=80), intent(in), optional :: hdr(:)
  integer :: iunit,blocksize,group,firstpixel,bitpix,npixels
  logical :: simple,extend

  !  Get an unused Logical Unit Number to use to open the FITS file.
  ierr = 0
  call ftgiou(iunit,ierr)

  !  Create the new empty FITS file.
  blocksize=1
  print "(a)",' writing '//trim(filename)
  call ftinit(iunit,filename,blocksize,ierr)

  !  Initialize parameters about the FITS image
  simple=.true.
  ! data size
  bitpix=-32
  extend=.true.

  !  Write the required header keywords.
  call ftphpr(iunit,simple,bitpix,2,naxes,0,1,extend,ierr)
  !  Write additional header keywords, if present
  if (present(hdr)) call write_fits_head(iunit,hdr,ierr)

  group=1
  firstpixel=1
  npixels = naxes(1)*naxes(2)
  ! write as real*4
  call ftppre(iunit,group,firstpixel,npixels,image,ierr)

  !  Close the file and free the unit number
  call ftclos(iunit, ierr)
  call ftfiou(iunit, ierr)

 end subroutine write_fits_image


!------------------------------------------------
! Writing new fits file
!------------------------------------------------
 subroutine write_fits_cube(filename,image,naxes,ierr,hdr)
   character(len=*), intent(in) :: filename
   integer, intent(in)  :: naxes(3)
   real(kind=4),     intent(in) :: image(naxes(1),naxes(2),naxes(3))
   integer, intent(out) :: ierr
   character(len=80), intent(in), optional :: hdr(:)
   integer :: iunit,blocksize,group,firstpixel,bitpix,npixels
   logical :: simple,extend
 
   !  Get an unused Logical Unit Number to use to open the FITS file.
   ierr = 0
   call ftgiou(iunit,ierr)
 
   !  Create the new empty FITS file.
   blocksize=1
   print "(a)",' writing '//trim(filename)
   call ftinit(iunit,filename,blocksize,ierr)
 
   !  Initialize parameters about the FITS image
   simple=.true.
   ! data size
   bitpix=-32
   extend=.true.

   !  Write the required header keywords.
   call ftphpr(iunit,simple,bitpix,3,naxes,0,1,extend,ierr)
   !  Write additional header keywords, if present
   if (present(hdr)) call write_fits_head(iunit,hdr,ierr)

   group=1
   firstpixel=1
   npixels = product(naxes)
   ! write as real*4
   call ftppre(iunit,group,firstpixel,npixels,image,ierr)
 
   !  Close the file and free the unit number
   call ftclos(iunit, ierr)
   call ftfiou(iunit, ierr)
 
 end subroutine write_fits_cube
 
!------------------------------------------------
! Extract tag:val pairs from fits header
! will extract anything readable as a floating
! point number
!------------------------------------------------
subroutine get_floats_from_fits_header(hdr,tags,vals)
 character(len=80), intent(in) :: hdr(:)
 character(len=*),  intent(out) :: tags(:)
 real,              intent(out) :: vals(:)
 integer :: i, n, ierr, ieq
 real :: val
  
 n = 0
 do i=1,size(hdr)
    ieq = index(hdr(i),'=')
    if (ieq > 0) then
       read(hdr(i)(ieq+1:),*,iostat=ierr) val
       if (ierr == 0) then
          n = n + 1
          if (n <= size(vals)) then
             tags(n) = hdr(i)(1:ieq-1)
             vals(n) = val
             !print*,'got ',tags(n),':',vals(n)
          endif
       endif
    endif
 enddo
  
end subroutine get_floats_from_fits_header

end module readwrite_fits
