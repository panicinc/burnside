Burnside
========

Panic's Burnside bridges Twitter to email and back.

It's particularly useful for companies that provide Twitter support. By handling @questions through an e-mail client, support agents can reply to tweets much quicker, answered tweets can be tracked by "Archiving" them or moving them to a subfolder, multiple agents can work out of the same mailbox (via IMAP), and an easily-searchable archive of tweets can be built over time.

**Burnside is intended for shell-level/e-mail server administrators**, and requires:

- Procmail (already working with user accounts on an IMAP/SMTP server)
- Cron
- Ruby
- SMTP server with "+" character recipient delimiter enabled for subaddressing

Other configurations may be possible based on your expertise.

Installation
------------

	sudo gem install bundler
	git clone https://github.com/panicinc/burnside
	cd burnside
	bundle install --deployment
	
Twitter Application
-------------------
Create a new [Twitter Application](https://dev.twitter.com/apps/new) and get its consumer key and secret as well as authorize your account to make use of it.

Configuration
-------------

Copy the .sample files and rename them appropriately. Fill in the details of the .yml file with the OAuth information you got when you created and authorized your application.

The `auth_token` field should contain a randomly generated password. An easy way to make one on Mac OS X is with

	dd if=/dev/urandom count=4 2>/dev/null | openssl dgst -sha1
	
Usage
-----

To bridge your tweets to email you'll run bin/fetch.rb as follows

	./bin/fetch.rb -c config/username.yml
	
This task could be run via cron like

	*/5 * * * * cd $HOME/burnside; ./bin/fetch.rb -c config/username.yml
	
To handle incoming email you'll need to setup Procmail. There's a sample recipe in the config folder.

Caveats
-------

Burnside was written to be used with Apple Mail so there are a few assumptions about how it formats emails.

Contributing
------------

Feel free to fork and send us pull requests

Bug Reporting
-------------

Burnside is an unsupported, unofficial Panic product. But, if you can't contribute directly, please file bugs as https://hive.panic.com in the Burnside project. You have to register first, via the Register link in the upper-right hand corner.