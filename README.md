# Vagrant Docker Drupal (VDD)
A Vagrant setup that uses Docker as provider, builds Docker images and creates Docker containers for running Drupal. Fully embrace the Docker principle: One Concern per Container.

## Introduction
The project can be a boilerplate for starting a new Drupal project, or integrating existing Drupal project into Docker styles. So that developers can have more control on the application environments, and sysadmin can rest assure that the deployment can go smoothly.

In summary, Vagrant will fire up a VM (ubuntu:14.04) and install a Docker daemon. Docker base image (ubuntu:14.04) will be used, and system services like Nginx, PHP-FPM, MySQL will be running inside individual containers. [Data Volume Container](https://docs.docker.com/userguide/dockervolumes/) will be used to hold persistent data.

## Prerequisite
- [Vagrant](https://www.vagrantup.com/downloads.html) >= v1.7.2
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- Vagrant Plugin:
  - [vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest)
  - (Windows) [vagrant-winnfsd](https://github.com/GM-Alex/vagrant-winnfsd) or similar tools to provide `nfs` service

A fast Internet and patient, because many images will be downloaded for the first time.

## Quick Start
1. Clone the git repository from Github

        git clone https://github.com/stevenyeung/vagrant-docker-drupal.git <project_code>

2. Change the variables in `project-init.sh`, this script will modify the VM hostname and IP in the config files
  - `PROJECT_CODE=<project_code>`
  - `DOCKER_HOST_IP=<host_only_ip>`

3. Execute `project-init.sh`

        bash ./project-init.sh

4. Use Vagrant to fire up your Docker Host VM, it will build the images and create containers automatically

        vagrant up --no-parallel

5. While Vagrant is busying provisioning your development environment, you may change your `hosts` file if you want to access the Drupal using hostname. Something like:

        <host_only_ip> <project_code>.local

6. When Vagrant finish provisioning (stop flooding), use a browser and visit `http://<project_code>.local`

7. The default Drupal admin account

        username: admin
        password: test

8. The installed Drupal directory is located at `./Docker/drupal/drupal`, and this folder is synced with the container. You may start Drupal development.

## Under The Hood
### Docker Images and Containers
The relationship between images and containers are shown as below:

*Containers are suggested to run as following order*

1. `syslog:devel`
  - `syslog`

2. `logrotate:devel`
  - `logrotate`

3. `exim:devel`
  - `exim`

4. `<PROJECT_CODE>-data-file:devel`
  - `<PROJECT_CODE>-data-file`

5. `<PROJECT_CODE>-data-sql:devel`
  - `<PROJECT_CODE>-data-sql`

6. `<PROJECT_CODE>-mysql:devel`
  - `<PROJECT_CODE>-mysql`

7. `<PROJECT_CODE>-drupal:devel`
  - `<PROJECT_CODE>-php-fpm`
  - `<PROJECT_CODE>-nginx`
  - `<PROJECT_CODE>-php-cron`

The `syslog:devel` image was bundled with `rsyslod` and some custom configs for managing Drupal and Nginx logs.  `logrotate:devel` image simply provides a logrotate cronjob to rotate the logs.

The `exim:devel` image was packed with `exim4-daemon-light`, and preconfigured to allow docker private ip ranges to use `SMTP`.

The `<PROJECT_CODE>-data-file:devel` image declares two volumes:
- `/var/www/drupal/sites/default/files`
- `/var/www/drupal/sites/default/private`

The `<PROJECT_CODE>-data-sql:devel` image declares one volume:
- `/var/lib/mysql`

And the created `<PROJECT_CODE>-data-file` and `<PROJECT_CODE>-data-sql`container will be used as Data Volume Container to hold persistent data.

The `<PROJECT_CODE>-mysql:devel` image was packed with MySQL-Server. The container `<PROJECT_CODE>-mysql` will mount the volume `/var/lib/mysql` from the `<PROJECT_CODE>-data-sql` data container.

The `<PROJECT_CODE>-drupal:devel` image was built with packages like Nginx, PHP-FPM, PHP-CLI, MySQL-Client, drush and Drupal source code. Since these services will need to access the Drupal source code, and in order to reduce the steps of packing Drupal source code into multiple images, they are included into the same image. So three containers with different roles will be created and serving the Drupal site. The three containers created will mount `/var/www/drupal/sites/default/files` and `/var/www/drupal/sites/default/private` from the `<PROJECT_CODE>-data-file` container.

### About Development
With the use of Vagrant, the project folder is synced by `nfs` to the Docker Host VM at `/vagrant`. The three containers
- `<PROJECT_CODE>-nginx`
- `<PROJECT_CODE>-php-fpm`
- `<PROJECT_CODE>-php-cron`

will mount the `/vagrant/Docker/drupal/drupal` into their container as `/var/www/drupal`. Therefore you are free to use your favrouite IDE, and editing the source code will directly shows the update in the containers.

Vagrant will default run the php-fpm with a php.ini-devel, which reports verbose error to assist development.

When working with emails in Drupal during development, better make use of `DevelMailLog` class from [Devel](http://drupal.org/project/devel) module or [Reroute Email](https://www.drupal.org/project/reroute_email) module. Any email address ending in `@mail.localdomain` will be forwarded to the `root` account in `exim` container. You may mount the `/var/mail/mail` from `exim` container for debugging.

### About Deployment in Production
Suppose you are using git, you may
- do any necessary backup, like db and file assets
- git pull the source code from your repository
- build and tag your latest image
- stop the current nginx, php-fpm, php-cron containers
- create new containers from your latest image
- run drush updatedb and clear cache if necessary
- if anything goes wrong, you may revert the db from your backup and resume the old containers
- otherwise, you may remove the old container and start using the latest one

### Security Concerns
Since Docker by default, allowing [inter-container-connections](https://docs.docker.com/articles/networking/#communication-between-containers) without restrictions. For security reasons, please modify `/etc/default/docker` and add `--iptables=true --icc=false` to the `DOCKER_OPTS` variable. After restarting docker, docker will default `DROP` packets in the forward chain and adding `ACCEPT` entries when using `--link` during `docker run`.

### Some Default Settings for New Drupal Installation.
- The Drupal default 'poor man' cron is disabled, since we have a specific container to do the background cronjob.
- Drupal core module `syslog` is enabled, and facility is being set as `local6`. Identity is set as `<PROJECT_CODE>`. Nginx's facility is set as `local7` and tag is set as `<PROJECT_CODE>` as well.
- Drupal module [SMTP Authentication Support](https://www.drupal.org/project/smtp) is downloaded and enabled. To turn on smtp support, please go to `admin/config/system/smtp` and click `On` in the first option.
- Devel module is also downloaded.

## Coming Features
- Some shortcuts to interact with containers, e.g. using drush commands
- A nice backup strategy
- Memcache container
- Varnish container
- Solr container

## FAQ
- Q: My workstation is a linux box and I am already using Docker for my projects, I don't want to use VirtualBox, or any other VM technologies.

  A: Yes, of course you can use Docker natively. Why the project requires a VirtualBox is because the synced folder location, which can be different depends on personal taste. To use native Docker, please edit the settings in `Vagrantfile`:

       d.force_host_vm = false
       d.volumes = ["<project_location>/Docker/drupal/drupal:/var/www/drupal"]

- Q: Can I run another Drupal project in this Vagrant setup?

  A: It is better to keep one Vagrant setup for one Drupal project, although the underlying technology is Docker. It is because we need to map another synced folder with the VM, and mount that folder as volumne inside containers. This might increase the complexity of your Vagrant setup.

- Q: If I want to run multiple Drupal projects in the production server, how to manage the Nginx and port 80?

  A: You may use the [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy) container to do a reverse proxy for you. It will automatically update Nginx proxy once you start/stop containers.

- Q: Why sometimes `vagrant up --no-parallel` fail?

  A: If you are seeing this error message:

        A Docker command executed by Vagrant didn't complete successfully!
        The command run along with the output from the command is shown
        below.

        Command: "docker" "build" "-t=exim:devel" "/mnt/docker_build_bff73e91c1e07810c0c6e278226833a0"

        Stderr: time="2015-01-19T07:45:22Z" level="fatal" msg="stat /mnt/docker_build_bff73e91c1e07810c0c6e278226833a0: no such file or directory"

  Check the error message, and see what it is building. In this case, it fails to build `exim`. So please run `vagrant reload exim`, and force vagrant to synced the build directory again. This is a known [bug](https://github.com/mitchellh/vagrant/issues/4775) in vagrant.

## Acknowledgments
Special thanks to [António](https://github.com/perusio) for the great [Nginx config for Drupal](https://github.com/perusio/drupal-with-nginx) and [PHP-FPM config](https://github.com/perusio/php-fpm-example-config).

The `entrypoint.sh` script for MySQL is based on the idea from [docker-library/mysql](https://github.com/docker-library/mysql).

The project idea is coming from [Blog Zenika](http://blog.zenika.com/index.php?post/2014/10/07/Setting-up-a-development-environment-using-Docker-and-Vagrant).

The way of centralized logging is coming from Jérôme's [blog](http://jpetazzo.github.io/2014/08/24/syslog-docker/).
