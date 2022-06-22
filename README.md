# Private Router Remote Access VPN WireGuard & Pihole Install Script

This script allows you to easily install PrivateRouter's Wireguard remote VPN.

To use first purchase Remote VPN service from PrivateRouter.com and note your IP address and token.

The script will install docker, Wireguard, wg-easy, pihole, and nginx proxy manager.

Below are the flags that you may pass to the script.

```
== rvpn-install.sh Flags (* Indicates Required) ==
* [-s 123.456.789.012]* sets the FRP Server Address
* [-t abcd12345]* sets the FRP Server Token
* [-d yourdomain.com ] sets the Domain Name for Reverse Proxy
* Example: rvpn-install.sh -s 123.456.789.012 -t abcd12345 -d myvpn.privaterouter.com
```

To install as a system service:

**`rvpn-install.sh -s [Server-IP] -t [Server-Token] -d myvpn.privaterouter.com`**



