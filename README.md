ssh_docker
==========

ssh/scp scripts for bouncing through docker server to containers from elsewhere

I needed some scripts to let me tunnel through my docker server to
the containers, from my laptop.  It was getting especially annoying
doing two hop copies manually.  So here's a crappy bash script.
Run without args to get usage.

If you alway use the same gateway, remote user, etc., put them in a config
file in ~/.ssh_docker, see ssh_docker_config.sample for more info.

To have less clutter from the scp script, you might consider making
your containers with PrintLastLog no in /etc/ssh/sshd_config.

This uses sshpass because these are throwaway test containers;
if you are using this setup for containers on a production cluster
then shame on you.

No you cannot scp from one container to another using this script
because I am lazy.  From your laptop/tablet/$other_device to/from
container is all you get.
