## Running on EC2

Currently we're on the 20.03 nixos release, but newer releases should work too.

An AMI ID may be found on the [nixos download
page](https://nixos.org/download.html).

You'll need to open the following ports in the security group:

| Open to        |    Ports  | Purpose                             |
|----------------|-----------|-------------------------------------|
| 0.0.0.0/0      | 6697-7001 | IRC (TLS)                           |
| 0.0.0.0/0      | 5999      | IRC (TLS)                           |
| 0.0.0.0/0      | 8501      | IRC (TLS)                           |
| 0.0.0.0/0      | 13001     | IRC (TLS)                           |
| 0.0.0.0/0      | 6665-6669 | IRC                                 |
| 0.0.0.0/0      | 4080      | IRC                                 |
| link server ip | 7005      | server&lt;-&gt;server communication |

### Setting it up

The initial user is 'root@'.

Bootstrapping up should be as simple as copying the
[example-configuration.nix](../example-configuration.nix) file to
`/etc/nixos/configuration.nix`, filling in all information, running
`nixos-rebuild switch`, and grabbing some coffee while it compiles everything
we don't have a binary cache for.
