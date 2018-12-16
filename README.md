lansmtpd
========

Project 'lansmtpd' is an SMTP daemon that delivers email to local users,
manages credentials and submits outgoing email to remote SMTP servers.  It
can be run on a home Linux server to serve all computers on the LAN as a
mail transfer agent (MTA).

Central Configuration
---------------------

Lansmtpd enables the consolidation of email configuration infomation.  Only
this daemon needs to know the email providers and credentials.

Mail user agents (MUAs) such as 'thunderbird', 'evolution', 'mailx' or
'mutt' on machines connected to the LAN may be configured to send all mail
to port 25 of the server on the LAN running lansmtpd.  Email sent through
lansmtpd addressed to any valid email address is submitted to a configured
SMTP server using the configured credentials of the provider account.

Windows machines may also be so configured.

Local Mail
----------

Email addressed to a local machine is delivered to the designated local
mailbox.\
E.g.: tim@mybox, anybody@localhost, root@mybox.localdomain, tim, root.

This allows cron or other software running on any PC on the home network
to send email such that it is received along with other incoming mail,
but without ever leaving the LAN or even requiring internet connectivity.

Although note that the cron daemon requires /usr/sbin/sendmail to deliver
email.  Therefore every computer that uses cron must have the 'sendmail'
package or a simpler substitute such as 'ssmtp' (recommended) installed
and configured to deliver email to the lansmtpd server.

Multiple users on PCs directly connected to the LAN may also send email to
each other this way if the recipients have accounts on the lansmtpd server.

Installation
------------

Verify these perl packages and software packages are installed.  Install
any missing packages:

    Net::IP
    Net::SMTP::SSL
    Net::SMTP::Server::Client
    ssmtp (or sendmail, etc.)
    maildrop (or another mail delivery agent)

If the Net::SMTP::Server::Client perl package is available, the provided
Client.pm file isn't needed.  Otherwise, install it as root:

    mkdir -p /usr/local/share/perl5/Net/SMTP/Server
    install -m444 Client.pm /usr/local/share/perl5/Net/SMTP/Server/

Install lansmtpd by executing these commands as root:

    install -m755 lansmtpd /usr/local/bin
    install -m600 lansmtpd.conf /usr/local/etc
    echo '/usr/local/bin/lansmtpd start' >> /etc/rc.d/rc.local

Edit and uncomment lines in /usr/local/etc/lansmtpd.conf appropriately.  The
configuration for each provider should be put in its own section identified
by the domain name in brackets, e.g. [comcast.net].  The "from" address on
outgoing email selects the section that's used.  Section [smtp] matches any
"from" address that wasn't matched by another section.

Configure ssmtp (or sendmail, etc.) on each participating machine on the
network to deliver email to the machine running lansmtpd.  You may only
need to set the 'mailhub' variable to the hostname of the server.

Startup
-------

The line added to /etc/rc.d/rc.local will start lansmtpd when the machine
is booted.  It may be started manually by executing this command as root:

    /usr/local/bin/lansmtpd start

Receiving Email
---------------

This daemon has nothing to do with receiving email, but it has limited
value without a complementary POP or IMAP configuration.  A suggested
setup is to run an IMAP daemon on the same server that runs lansmtpd, and
use fetchmail to pull email received by email providers.

The [uw-imap](http://www.washington.edu/imap/) and
[fetchmail](http://www.fetchmail.info/) packages are available in many
Linux repositories.

There are advantages of this setup.

  - Email from multiple providers can be consolidated in one local inbox.

  - Inbox size limits imposed by email providers are irrelevant as email
    is stored locally.

  - Email sent locally, such as by cron on any machine on the LAN, can be
    delieverd to the same inbox with external email, even when the
    internet connection is down.

  - Popular email clients such as Thunderbird running on multiple machines
    on the LAN can present the same inbox simultaneously with no conflict.
