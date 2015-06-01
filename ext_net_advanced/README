PRISMA Network Administrator Script  
======


Introduction
--

This python script return information about the status of OpenStack ext_net network in terms of available and allocated IPs.

Installation
--

For use this script you must have Python 2.7 and modules present in requirements.txt
If you don't have this moudles you can run:

<pre>
# pip install -r requirements.txt
</pre>

How to use
-- 

Run your script for access to OS as an administrator:

<pre>
# ./admin-openrc.sh
</pre>

and run the script:

<pre>
# ./main.py
</pre>

The output is something like this:

<pre>
+-------------------------------+-------+
| Range                         | Total |
+-------------------------------+-------+
| 192.168.0.104 - 192.168.0.120 | 16    |
+-------------------------------+-------+
+---------------+------------------------+-------------------------------------------+
|       IP      | Owner                  | Name                                      |
+---------------+------------------------+-------------------------------------------+
| 192.168.0.104 | network:router_gateway | Ext_Router                                |
| 192.168.0.105 |                        |                                           |
| 192.168.0.106 | network:floatingip     | MyTestVM1                                 |
| 192.168.0.107 | network:router_gateway | default                                   |
| 192.168.0.108 | network:floatingip     | MyTestVM2                                 |
| 192.168.0.109 |                        |                                           |
| 192.168.0.110 |                        |                                           |
| 192.168.0.111 |                        |                                           |
| 192.168.0.112 |                        |                                           |
| 192.168.0.113 |                        |                                           |
| 192.168.0.114 |                        |                                           |
| 192.168.0.115 |                        |                                           |
| 192.168.0.116 |                        |                                           |
| 192.168.0.117 |                        |                                           |
| 192.168.0.118 |                        |                                           |
| 192.168.0.119 |                        |                                           |
| 192.168.0.120 |                        |                                           |
+---------------+------------------------+-------------------------------------------+
+------------+-------+
| Property   | Value |
+------------+-------+
| Associated |  4    |
| Free       | 12    |
| Total      | 16    |
+------------+-------+
</pre>

Copyright and license
--

The content of this repository is released under the Apache 2.0 License as provided in the LICENSE file that accompanied this code.
