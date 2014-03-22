#!/bin/bash

# find the first arg in the args list which doesn't start
# with - and swap it for an ip address
# then call ssh on it, going via the below gateway as
# proxy host

usage() {
    echo "usage: $0 [options] hostspec [command]"
    echo
    echo "hostspec consists of [user@]container-name"
    echo
    echo "options may be ssh options or one of the following:"
    echo
    echo "-ID  path to identity file to use for connecting to gateway (server running containers)"
    echo "-GW  ip or hostname of gateway"
    echo "-RU  remote user on container"
    echo "-RP  remote password for container"
    echo
    echo "example: $0 puppet-mar14 ls"
    echo
    echo "config file may be placed in $HOME/.ssh_docker with definitions for gateway, remote"
    echo "user/password, identity file for ssh to gateway."
    exit 1
}

setup_defaults() {
    config="$HOME/.ssh_docker"
    if [ -e "$config" ]; then
        source "$config"
    else
        # fixme should be able to override on the
        # command line
        gateway="1.2.3.4"
        remoteuser="root"
        remotepassword="1234"
        identity="$HOME/.ssh/id_rsa"
    fi
}

get_overrides() {
    args=()
    for (( i=1; i<=$#; i++ ))
    do
        a=${!i}
        case $a in
    	-GW*)
    	    if [ "${#a}" == "3" ]; then
    		(( i++ ))
    		gateway=${!i}
    	    elif [ "${a:3:1}" == '=' ]; then
    		gateway=${a:4}
                else
    		gateway=${a:3}
                fi
    	    ;;
    	-ID*)
    	    if [ "${#a}" == "3" ]; then
    		(( i++ ))
    		identity=${!i}
    	    elif [ "${a:3:1}" == '=' ]; then
    		identity=${a:4}
                else
    		identity=${a:3}
                fi
    	    ;;
    	-RU*)
    	    if [ "${#a}" == "3" ]; then
    		(( i++ ))
    		remoteuser=${!i}
    	    elif [ "${a:3:1}" == '=' ]; then
    		remoteuser=${a:4}
                else
    		remoteuser=${a:3}
                fi
    	    ;;
    	-RP*)
    	    if [ "${#a}" == "3" ]; then
    		(( i++ ))
    		remotepassword=${!i}
    	    elif [ "${a:3:1}" == '=' ]; then
    		remotepassword=${a:4}
                else
    		remotepassword=${a:3}
                fi
    	    ;;
            *)
    	    args+=($a)
    	    ;;
        esac
    done
}

check_missing_config_args() {
    if [ -z "$gateway" ]; then
        echo "gateway must be specified in config $config"
        usage
    fi
    if [ -z "$remoteuser" ]; then
        echo "remoteuser must be specified in config $config"
        usage
    fi
    if [ -z "$remotepassword" ]; then
        echo "remotepassword must be specified in config $config"
        usage
    fi
    if [ -z "$identity" ]; then
        echo "identity must be specified in config $config"
        usage
    fi
}

start_ssh_agent() {
    mkdir -p /tmp/ssh-dockergw
    running=`pgrep -f /tmp/ssh-dockergw/agent.dockergw`
    if [ -z "$running" ]; then
        if [ -e /tmp/ssh-dockergw/agent.dockergw ]; then
            rm -f /tmp/ssh-dockergw/agent.dockergw
        fi
        ssh-agent -s -a /tmp/ssh-dockergw/agent.dockergw
        identity_needed="y"
    fi
}

setup_environment() {
    SSH_AUTH_SOCK=/tmp/ssh-dockergw/agent.dockergw
    SSH_AGENT_PID=`pgrep -f /tmp/ssh-dockergw/agent.dockergw`
    if [ -z "$SSH_AGENT_PID" ]; then
        echo "failed to start or find ssh agent, giving up"
        rm -f /tmp/ssh-dockergw/agent.dockergw
        exit 1
    fi
    export SSH_AUTH_SOCK SSH_AGENT_PID
}

add_identity() {
    if [ -n "${identity_needed}" ]; then
        ssh-add $identity
    fi
}

get_ip() {
    IP=`ssh $gateway -i "$identity" docker inspect '-format={{.NetworkSettings.IPAddress}}' "$host"`
    if [ -z "$IP" ]; then
        echo "Error, no ip found, exiting"
        exit 1
    fi
}

process_args() {
    for (( i=0; i<${#args[@]}; i++ ))
    do
        case ${args[$i]} in
	    # ssh [-1246AaCfgKkMNnqsTtVvXxYy] ...
	    -1|-2|-4|-6|-A|-a|-C|-f|-g|-K|-k|-M|-N|-n|-q|-s|-T|-t|-V|-v|-X|-x|-Y|-y)
		;;
            -*)
                # opt length 2 chars means the value is the next arg
                # so skip it too                
                if [ "${#args[$i]}" -eq "2" ]; then
                    (( i++ ))
                fi
                ;;
            *)
                host="${args[$i]}"
                ind=$i
                break
                ;;
        esac
    done
    if [ -z "$host" ]; then
        usage
    fi
}

function do_ssh {
    command="ssh -q -i ${identity} -a -W ${IP}:22 $gateway"
    prev=$ind
    next=$(( $ind + 1 ))
    # without -t -t it whines for scp: Pseudo-terminal will not be allocated because stdin is not a terminal.
    sshpass -p "$remotepassword" ssh  "-t" "-t" "-l" "$remoteuser" "-o" "ProxyCommand ${command}" ${args[@]:0:$prev} ${IP} ${args[@]:$next}
}

function cleanup {
    unset SSH_AUTH_SOCK
    unset SSH_AGENT_PID
}

setup_defaults
get_overrides $@
check_missing_config_args
start_ssh_agent
setup_environment
add_identity
process_args
get_ip
do_ssh
cleanup
