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
	
Usage
-----

To bridge your tweets to email you'll run bin/fetch.rb as follows

	./bin/fetch.rb -c config/username.yml
	
This task should be run via cron like

	*/5 * * * * cd $HOME/burnside; ./bin/fetch.rb -c config/username.yml
	
To handle incoming email you'll need to setup Procmail. There's a sample recipe in the config folder.

Contributing
------------

Feel free to fork and send us pull requests