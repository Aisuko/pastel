# RHEL9

This folder includes script for automatically installing Docker CE (28.0.1) and Docker Compose (2.33.1) to RHEL 9 in Rootless mode.


# How to use it?

```shell
sudo ./install-docker-rootless.sh --user-name ec2-user
```


# Default value

```python
DOCKER_VERSION="28.0.1-1.el9"
USER_NAME="ec2-user"  # Adjust if using a different non-root user
```

# Support Testing Environment

RHEL 9
```
Linux ip-10-0-1-141.ap-southeast-2.compute.internal 5.14.0-503.34.1.el9_5.x86_64 #1 SMP PREEMPT_DYNAMIC Mon Mar 17 21:49:47 EDT 2025 x86_64 x86_64 x86_64 GNU/Linux
```

dnf
```shell
4.14.0
  Installed: dnf-0:4.14.0-17.el9.noarch at Mon Mar 31 03:20:47 2025
  Built    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla> at Tue Aug  6 11:11:05 2024

  Installed: rpm-0:4.16.1.3-34.el9.x86_64 at Mon Mar 31 03:20:45 2025
  Built    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla> at Thu Aug 15 09:07:36 2024
```
