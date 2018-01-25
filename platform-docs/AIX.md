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

9. Select `IBM AIX 7.2` from `Select an image`.

10. Click `Add Resources to project`.

11. Click `Create project and reservation`.

#### Preparing the AIX instance for builds

1. SSH into the AIX instance with the user provided by IBM (e.g. u0022222) and change the password.

2. Use the `su` command to switch to the root user.

3. (Optional) Change the root password.

4. Change to the root directory:

  ```sh
  cd /
  ```

5. Update the partition sizes:

  ```sh
  chfs -a size=+7G /
  chfs -a size=+3G /opt
  chfs -a size=+2G /usr
  chfs -a size=+2G /var
  chfs -a size=+1G /home
  ```

6. Download the Omnibus toolchain and install it:

  ```sh
  export OMNIBUS_TOOLCHAIN_VERSION=1.1.73
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "https://packages.chef.io/files/stable/omnibus-toolchain/${OMNIBUS_TOOLCHAIN_VERSION}/aix/7.1/omnibus-toolchain-${OMNIBUS_TOOLCHAIN_VERSION}-1.powerpc.bff" > omnibus-toolchain.bff
  installp -aXY -d omnibus-toolchain.bff omnibus-toolchain
  ```

7. Download the Omnibus environment script and source it:

  ```sh
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "https://raw.githubusercontent.com/sensu/sensu-omnibus/master/load-omnibus-toolchain.sh" > load-omnibus-toolchain.sh
  . ./load-omnibus-toolchain.sh
  ```

8. Configure git name and email:

  ```sh
  git config --global user.email "justin@sensu.io"
  git config --global user.name "Justin Kolberg"
  ```

9. Install `sudo` and `coreutils`:

  ```sh
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/sudo/sudo-1.8.15-1noldap.aix6.1.ppc.rpm
  rpm -i ftp://ftp.software.ibm.com/aix/freeSoftware/aixtoolbox/RPMS/ppc/coreutils/coreutils-5.2.1-2.aix5.1.ppc.rpm
  ```

10. Increase the maximum memory that processes are allowed to use:

  ```sh
  export LDR_CNTRL=MAXDATA=0x80000000
  ```

#### Running a build

1. Clone the sensu-omnibus git repository:

  ```sh
  git clone https://github.com/sensu/sensu-omnibus.git
  ```

2. Change to the sensu-omnibus directory:

  ```sh
  cd sensu-omnibus
  ```
  
3. Check out the desired tag of sensu-omnibus, e.g. `v1.2.0-1` branch:

  ```sh
  git checkout v1.2.0-1
  ```

4. Install gem dependencies:

  ```sh
  bundle install
  ```

5. Export version environment variables:

  ```sh
  export SENSU_VERSION=x.y.z
  export BUILD_NUMBER=1
  ```

6. Build Sensu:

  ```sh
  bundle exec omnibus build sensu -l debug
  ```

7. Upload packages:

  ```sh
  export AWS_ACCESS_KEY_ID=replaceme
  export AWS_SECRET_ACCESS_KEY=replaceme
  export AWS_REGION=us-east-1
  export AWS_S3_ARTIFACT_BUCKET=sensu-omnibus-artifacts
  bundle exec omnibus publish s3 sensu-omnibus-artifacts pkg/*.bff
  ```
