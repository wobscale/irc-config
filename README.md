# Wobscale IRC Config

This is the home of configuration and documentation related to the running of the Wobscale IRC Network

## Example manual configuration

Currently, all documentation expects that you're running Container Linux by CoreOS.

If you're on AWS, I recommend creating an EIP and associating it to the instance.

Make sure the following ports are allowed: 6697-7001,5999,8501,13001,6665-6669,4080

`sudo hostnamectl set-hostname $name`
