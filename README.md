Burnside
========

Burnside bridges twitter to email.

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
	
To bridge your email back to twitter get Procmail setup and then use the following recipe

	:0
	* !^X-Burnside: ignore
	{
		# Pipe the email into tweet.rb
		:0 W
		* !^FROM_DAEMON
		ERROR=|/usr/bin/ruby $HOME/burnside/bin/tweet.rb -c $HOME/burnside/config/username.yml
		# If that fails
		:0 e
		{
		 # Data format error
		 EXITCODE=65 
		 :0
		 /dev/null
		}
		# Delete successful tweets
		:0:
		/dev/null
	}

Contributing
------------

Feel free to fork and send us pull requests