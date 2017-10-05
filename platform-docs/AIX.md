### AIX 7.x (powerpc)

**NOTE: Ensure the date is correctly set before following any of the AIX guides.**

#### Requesting an AIX instance

**NOTE: Caleb's IBM id is the only account that currently can spin up instances**

1. Sign into the Power Development Cloud website
(https://www-356.ibm.com/partnerworld/wps/ent/pdp/web/MyProgramAccess).

2. Select `Virtual Server Access` from the `Please select a program` dropdown.

3. Enter a project name of `sensu-client`.

4. Enter a project description of `sensu-client build box`.

5. Select `Existing customer support` from `Project opportunity`.

6. Select `Build and test` from `Project classification`.

7. Ensure the start date is at least two hours from the current time. This is
unfortunately the least amount of time needed for AIX instance requests. The
actual time that it takes for the instance to spin up can sometimes be less
than two hours.

8. Ensure the end date is long enough for builds/tests to be run.

9. Select `IBM AIX 6.1` from `Select an image`.

10. Unless you will be building a new Saved Image, select `Saved image` from
`Select an image type` and `aix-6_1-with-xl-deps-2` from `Select an image`.

11. Click `Add Resources to project`.

12. Click `Create project and reservation`.

#### Building a new Saved Image

1. SSH into the AIX instance as root and run the following commands:

  ```sh
  chfs -a size=+7G /
  chfs -a size=+3G /opt
  chfs -a size=+3G /usr
  chfs -a size=+3G /var
  ```

2. Download the AIX 6.1 ISO and mount it:

  ```sh
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "PATH_TO_AIX_ISO_HERE" > aix.iso
  mkdir /cdrom
  loopmount -i aix.iso -o "-V cdrfs -o ro" -m /cdrom
  ```

3. Install the prerequesites needed for IBM XL C/C++:

  ```sh
  installp -acXgd /cdrom bos.adt.include
  installp -acXgd /cdrom bos.adt.lib
  installp -acXgd /cdrom bos.adt.libm
  installp -acXgd /cdrom bos.rte
  installp -acXgd /cdrom bos.rte.libc
  installp -acXgd /cdrom bos.loc.utf.EN_US
  ```

4. Create the Saved Image by right-clicking the reservation ID on the IBM PDP
website and click `Save image`.

#### Installing the XL C/C++ compiler trial for AIX

1. Make a new directory to store the IBM XL C/C++ installation files:

  ```sh
  mkdir /ibmxl_install
  cd /ibmxl_install
  ```

2. Download the IBM XL C/C++ trial:

  ```sh
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "PATH_TO_IBM_XL_C_CPP_HERE" > "ibm_xl.tar.Z"
  ```

3. Uncompress and extract IBM XL C/C++:

  ```sh
  zcat ibm_xl.tar.Z | tar -xvf -
  ```

4. Install IBM XL C/C++:

  ```sh
  installp -aXYgd usr/sys/inst.images all
  ```

#### Preparing the AIX instance for builds

1. Remove any gcc packages that may cause issues later on:

  ```sh
  rpm -e libstdc++ libstdc++-devel libgcc gcc-c++ gcc gcc-locale gmp mpfr libmpc gcc-cpp
  ```

2. Remove `pkg-config` because it interferes with the Ruby build:

  ```sh
  rpm -e pkg-config
  ```

3. Install the base tools:

  ```sh
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/wget/wget-1.9.1-3.aix6.1.ppc.rpm
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/sudo/sudo-1.8.15-1noldap.aix6.1.ppc.rpm
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/bash/bash-4.3.30-1.aix6.1.ppc.rpm
  ```

4. Install zlib:

  ```sh
  rpm -U ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/zlib/zlib-1.2.8-1.aix6.1.ppc.rpm
  rpm -U ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/zlib/zlib-devel-1.2.8-1.aix6.1.ppc.rpm
  ```

5. Install GNU tar:

  ```sh
  rpm -U ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/tar/tar-1.22-1.aix6.1.ppc.rpm
  ```

6. Change limits:

  ```sh
  chsec -f /etc/security/limits -s default -a "data=-1"
  chsec -f /etc/security/limits -s default -a "rss=-1"
  chsec -f /etc/security/limits -s default -a "nofiles=50000"
  ```

7. Set the PATH environment variable in in `/.bash_profile`:

  ```sh
  echo 'export PATH=/opt/IBM/xlC/13.1.3/bin:/opt/IBM/xlc/13.1.3/bin:/usr/bin:/etc:/usr/sbin:/usr/local/bin:/opt/freeware/bin:/usr/ucb:/sbin:/usr/lpp/X11/bin:' >> ~/.bash_profile
  ```

8. Allow `bash` as a shell and make `bash` the default shell:

  ```sh
  echo '/usr/bin/bash' >> /etc/shells
  chsec -f /etc/security/login.cfg -s usw -a "shells=/bin/sh,/bin/bsh,/bin/csh,/bin/ksh,/bin/tsh,/bin/ksh93,/usr/bin/sh,/usr/bin/bsh,/usr/bin/csh,/usr/bin/ksh,/usr/bin/tsh,/usr/bin/ksh93,/usr/bin/rksh,/usr/bin/rksh93,/usr/sbin/uucp/uucico,/usr/sbin/sliplogin,/usr/sbin/snappd,/usr/bin/bash"
  chsh root /usr/bin/bash
  exit
  ```

9. After reconnecting to SSH, install `make` and `coreutils`:

  ```sh
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/make/make-3.81-1.aix6.1.ppc.rpm
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/coreutils/coreutils-5.2.1-2.aix5.1.ppc.rpm
  ```

10. Install a newer version of `wget`:

  ```sh
  cd /
  wget http://ftp.gnu.org/gnu/wget/wget-1.15.tar.gz
  gtar xzf wget-1.15.tar.gz
  cd wget-1.15
  CC=xlc_r ./configure --with-ssl=openssl --enable-largefile
  CC=xlc_r make
  CC=xlc_r make install
  rpm -e wget
  cd ..
  source ~/.bash_profile
  ```

11. Install the latest version of `openssl`:

  ```sh
  wget --no-check-certificate https://www.openssl.org/source/openssl-1.0.1t.tar.gz
  gtar xf openssl-1.0.1t.tar.gz
  cd openssl-1.0.1t
  OBJECT_MODE=32 ./Configure aix-cc shared
  OBJECT_MODE=32 make depend
  OBJECT_MODE=32 make
  slibclean
  OBJECT_MODE=32 make install
  cd ..
  ```

12. Install the default cacert bundle:

  ```sh
  mkdir -p /usr/local/ssl/certs
  wget --no-check-certificate -O /usr/local/ssl/certs/cacert.pem http://curl.haxx.se/ca/cacert.pem
  wget --no-check-certificate -O /var/ssl/cert.pem http://curl.haxx.se/ca/cacert.pem
  ```

13. Install a newer version of `curl` and link it against `openssl`:

  ```sh
  wget --no-check-certificate https://curl.haxx.se/download/curl-7.49.1.tar.gz
  gtar xf curl-7.49.1.tar.gz
  cd curl-7.49.1
  ./configure --with-ssl=/usr/local/ssl --with-ca-bundle=/usr/local/ssl/certs/cacert.pem
  make
  make install
  cd ..
  ```

14. Install `sed` and `expat`:

  ```sh
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/sed/sed-4.1.1-1.aix5.1.ppc.rpm
  rpm -U ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/expat/expat-2.2.0-1.aix6.1.ppc.rpm
  rpm -U ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/expat/expat-devel-2.2.0-1.aix6.1.ppc.rpm
  ```

15. Install `m4` and `autoconf`:

  ```sh
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/m4/m4-1.4.13-1.aix6.1.ppc.rpm
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/autoconf/autoconf-2.69-1.aix6.1.noarch.rpm
  ```

16. Install `git`:

  ```sh
  wget --no-check-certificate -O git.tar.gz https://github.com/git/git/archive/v2.8.3.tar.gz
  gtar xf git.tar.gz
  cd git-2.8.3
  autoconf
  ./configure --with-curl=/usr/local --without-tcltk
  sed -e 's#va_copy#aix_va_copy#' strbuf.c > strbuf.c.bak && mv strbuf.c.bak strbuf.c
  sed -e 's#define va_copy#define aix_va_copy#' git-compat-util.h > git-compat-util.h.bak && mv git-compat-util.h.bak git-compat-util.h
  sed -e 's#^INSTALL = install#INSTALL = /opt/freeware/bin/install#' Makefile > Makefile.bak && mv Makefile.bak Makefile
  gmake
  gmake install
  cd ..
  git config --global user.email "justin@sensu.io"
  git config --global user.name "Justin Kolberg"
  ```

17. Install `patch`:

  ```sh
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/patch/patch-2.5.4-4.aix4.3.ppc.rpm
  ```

18. Install `libffi`:

  ```sh
  wget ftp://sourceware.org/pub/libffi/libffi-3.1.tar.gz
  gtar xf libffi-3.1.tar.gz
  cd libffi-3.1
  INSTALL=/opt/freeware/bin/install ./configure
  gmake
  gmake install
  cd ..
  ```

19. Install `ruby`:

  ```sh
  wget --no-check-certificate https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.1.tar.gz
  gtar xf ruby-2.3.1.tar.gz
  cd ruby-2.3.1
  LDFLAGS="-L/usr/local/lib" CFLAGS="-qlanglvl=extc99 -I/usr/local/include -I/usr/local/lib/libffi-3.1/include" ./configure --disable-install-rdoc
  make
  make install
  cd ..
  ```

20. Install `bundler`:

  ```sh
  gem install bundler --no-ri --no-rdoc
  ```

21. Install `awk`:

  ```sh
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/gawk/gawk-3.1.3-1.aix5.1.ppc.rpm
  ```
