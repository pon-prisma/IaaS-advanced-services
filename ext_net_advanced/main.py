# Copyright 2015 PRISMA - PiattafoRme cloud Interoperabili per SMArt-government 
# Copyright 2015 Sielte S.p.A. - Salvatore Davide Rapisarda (sa.rapisarda@sielte.it)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import logging
import os
import socket
import struct

import argparse
from keystoneclient.auth.identity import v2
from neutronclient.neutron import client
from novaclient import client as nova_client
from prettytable import PrettyTable
import requests.packages

DESCRIPTION = "OpenStack Tools"
LOG = logging.getLogger('ostools')
requests.packages.urllib3.disable_warnings()


def get_client():
    return (client.Client('2.0',
                          auth_url=os.environ['OS_AUTH_URL'],
                          username=os.environ['OS_USERNAME'],
                          tenant_name=os.environ['OS_TENANT_NAME'],
                          password=os.environ['OS_PASSWORD'],
                          insecure=True,
                          ),
            nova_client.Client("2",
                               os.environ['OS_USERNAME'],
                               os.environ['OS_PASSWORD'],
                               os.environ['OS_TENANT_NAME'],
                               auth_url=os.environ['OS_AUTH_URL'],
                               insecure=True,)
            )


def main():
    ips = {}
    ips2router, ips2server = {}, {}
    servers = {}
    neutron, nova = get_client()

    for vm in nova.servers.list(search_opts={'all_tenants': 1}):
        servers[vm.id] = vm.name

    kwargs = {'router:external': True}

    ext_net = neutron.list_networks(**kwargs)['networks']
    ext_subnet = neutron.show_subnet(ext_net[0]['subnets'][0])

    allocation_table = PrettyTable(['Range', 'Total'])
    allocation_table.align['Range'] = 'l'
    allocation_table.align['Total'] = 'l'

    # Inizializzo la tabella degli IP
    for pool in ext_subnet['subnet']['allocation_pools']:
        for i in range(ip2int(pool['start']), ip2int(pool['end']) + 1):
            ips[int2ip(i)] = ''
        v1 = '%s - %s' % (pool['start'], pool['end'])
        v2 = ip2int(pool['end']) - ip2int(pool['start'])
        allocation_table.add_row([v1, v2])
    print allocation_table

    # Verifico gli indirizzi IP pubblici associati ai server
    for fips in neutron.list_floatingips()['floatingips']:
        if fips['port_id']:
            port = neutron.show_port(fips['port_id'])['port']
            key = fips['floating_ip_address']
            if port['device_id'] in servers:
                value = servers[port['device_id']]
            else:
                value = '-----'
            ips2server[key] = value
    # Verifico gli indirizzi IP pubblici associati al router

    for router in neutron.list_routers()['routers']:
        kwargs = {'device_id': router['id'], 'network_id': ext_net[0]['id']}
        for port in neutron.list_ports(**kwargs)['ports']:
            ips2router[port['fixed_ips'][0]['ip_address']] = router['name']

    kwargs = {'network_id': ext_net[0]['id']}

    for port in neutron.list_ports(**kwargs)['ports']:
        ip = port['fixed_ips'][0]['ip_address']
        key = ip
        ips[key] = '%s' % (port['device_owner'])

    free_ips = 0
    assigned_ips = 0

    tableip = PrettyTable(["IP", "Owner", "Name"])
    tableip.align["Owner"] = "l"
    tableip.align["Name"] = "l"

    for k in sorted(ips, key=my_key):
        if ips[k] == '':
            free_ips += 1
        else:
            assigned_ips += 1

        if "gateway" in ips[k]:
            tableip.add_row([k, ips[k], ips2router[k]])
        elif "floatingip" in ips[k]:
            if k in ips2server:
                tableip.add_row([k, ips[k], ips2server[k]])
            else:
                tableip.add_row([k, ips[k], ''])
        else:
            tableip.add_row([k, ips[k], ''])
    print tableip
    summary_table = PrettyTable(["Property", "Value"])
    summary_table.align["Property"] = "l"
    summary_table.align["Value"] = "l"
    summary_table.add_row(["Associated", assigned_ips])
    summary_table.add_row(["Free", free_ips])
    summary_table.add_row(["Total", len(ips)])
    print summary_table


def ip2int(addr):
    return struct.unpack("!I", socket.inet_aton(addr))[0]


def int2ip(addr):
    return socket.inet_ntoa(struct.pack("!I", addr))


def split_ip(ip):
    """Split a IP address given as string into a 4-tuple of integers."""
    return tuple(int(part) for part in ip.split('.'))


def my_key(item):
    return split_ip(item)


def setup_logging(args):
    level = logging.INFO
    if args.debug:
        level = logging.DEBUG
    logging.basicConfig(level=level)


def parse_args():
    # ensure environment has necessary items to authenticate
    for key in ['OS_TENANT_NAME', 'OS_USERNAME', 'OS_PASSWORD',
                'OS_AUTH_URL']:
        if key not in os.environ.keys():
            LOG.exception("Your environment is missing '%s'")

    ap = argparse.ArgumentParser(description=DESCRIPTION)
    ap.add_argument('-d', '--debug', action='store_true',
                    default=False, help='Show debugging output')
    return ap.parse_args()

if __name__ == '__main__':
    args = parse_args()
    setup_logging(args)
    main()
