Burnside
========

Burnside bridges twitter to email and back.

Installation
------------

	sudo gem install bundler
	git clone https://github.com/panicinc/burnside
	cd burnside
	bundle install --deployment
	
Twitter Application
-------------------
You'll need to make a Twitter Application and get its consumer key and secret as well as authorize
your account to make use it.

	
Configuration
-------------

You'll need to copy the two .sample files and rename them appropriately. Fill in the details of the
of the .yml file with the OAuth information you got when you created and authorized your application.

The `auth_token` field should contain a randomly generated password. A nice way to make one on Mac OS X
is with

	dd if=/dev/urandom count=4 2>/dev/null | openssl dgst -sha1
	
Usage
-----

To bridge your tweets to email you'll run bin/fetch.rb as follows

	./bin/fetch.rb -c config/username.yml
	
This task should be run via cron like

	*/5 * * * * cd $HOME/burnside; ./bin/fetch.rb -c config/username.yml
	
To handle incoming email you'll need to setup Procmail. There's a sample recipe in the config folder.

Caveats
-------

Burnside was written to be used with Apple Mail so there are a few assumptions about how it formats emails.

Contributing
------------

Feel free to fork and send us pull requests