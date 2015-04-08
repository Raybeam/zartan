# Zartan
Web UI to create and manage http proxies from one or more sources.

Web scrapers, crawlers or spiders are programs designed to automatically
go to one or more websites and download content from them.  A well-behaved
scraper will read that site's robots.txt file to determine which pages its
allowed to read.  Not all scrapers are well-behaved.  Often a website
has valuable information available to the public that the maintainers of
that site only want humans to use.

If you write a scraper targeting one such website then the second line of
defense against your scraper is to blacklist your server's IP address.
In order to continue scraping you need to change your apparent IP address
frequently.  One such way to do this is to use HTTP proxies.

Zartan will automatically create proxies from one or more sources and serve
them to your web scraper through a RESTful API.  Zartan will maintain separate
pools of proxies for each website you scrape, allowing you to use the same
proxies to scrape multiple sites, even if specific proxies have been banned
on specific sites.

It is expected that you run Zartan on your own server.  This is not a web
service.

# API Usage
All of the below GET and PUT requests require an api_key parameter.  The
responses are all JSON.  If the api_key is missing or invalid, the response is:
```
{"result":"error","reason":"Unrecognized API Key"}
```
Go to the admin panel, generate
an api_key and use that when making further requests.

## Get a new proxy
```
GET http://HOST_NAME/v1/SITE_NAME
```
Parameters
- older_than (optional)
  - How many seconds a proxy must remain idle before being used again

### On success
```
{
  "result":"success",
  "payload":{
    "id":11,
    "host":"IP_ADDRESS",
    "port":PORT_NUMBER,
    "source_id":2,
    "deleted_at":null,
    "created_at":"2015-03-10T15:57:17.014Z",
    "updated_at":"2015-04-07T18:14:55.850Z"
  }
}
```

### Failure: No proxies available
```
{"result":"please_retry","interval":20}
```
This either happens when there are no proxies newer than the optional older_than
parameter, or there are no proxies available at all.  In both cases, the
client is asked to wait `interval` seconds before they make another request.

## Report proxy success
```
PUT http://HOST_NAME/v1/SITE_NAME/11/succeeded
```
Informs zartan that the proxy with id #11 has successfully scraped a page.
In the short term, this resets the proxy's idle time.  In the long term,
this is used to evaluate whether the proxy is still able to scrape the
specified site

## Report proxy failure
```
PUT http://HOST_NAME/v1/SITE_NAME/11/failed
```
Informs zartan that the proxy with id #11 failed to scrape a page.
In the short term, this resets the proxy's idle time.  In the long term,
this is used to evaluate whether the proxy is still able to scrape the
specified site.

# Admin panel
The admin panel uses google OAUTH to authenticate.  If google manages your
email then authentication simply requires whitelisting your email domain in
config/default_settings.yml.

## Sites
A Zartan `Site` object represents a website you're targeting with your
scrapers. Zartan needs to know what site the proxy is being used on so
that it can keep track of which proxies have been banned on which sites.

### Configuration
- min_proxies
  - If there are fewer than this many proxies available for this site then
  zartan will try to provision more
- max_proxies
  - The maximum number of proxies to request/provision for the site.

## Sources
A Zartan `Source` object represents a proxy provider.  Typically this will be a
cloud services
provider, but it could be any external entity capable of providing http proxies.
Creating a Source object requires an account with that provider.  If that
provider is a cloud services provider then you are responsible for creating
the initial image of that proxy.  We recommend creating the smallest server
allowed and installing tiny_proxy on it.

Cloud service providers will typically allow you to create servers in multiple
geographic regions.  If you want proxies from multiple regions, then create 3
Source objects with the same API/login credentials, but different regions.

### Configuration
- Type
  - There can be many different types of Sources.  Typically this is
  a cloud services provider.  Creating a new Type requires subclassing the
  `Source` model.  See [Technical details](#technical-details).
- Max Proxies
  - Do not request or provision more than this many proxies from this Source.
- Reliability Score
  - It's possible, however unlikely, that two different sources can provide the
  same IP address + port.  If that were to happen, the Source with the higher
  Reliability Score will take ownership of that proxy.
- Other
  - Any other configuration parameters are specific to the Type of Source.

#### Digital Ocean
- proxy_port
  - What port is exposed for proxy services on the droplet image.
- client_id
  - get at https://cloud.digitalocean.com/api_access
- api_key
  - get at https://cloud.digitalocean.com/api_access
- image_name
  - It's assumed that you have provisioned a server on your own and saved
  an image with this name.  New proxies get created using this image.
- flavor_name
  - We recommend the '512MB' flavor
- region_name
  - This could be `New York 3`, `San Francisco 1`, etc.

If any of the information entered above information is inaccurate
then warning messages should
show up on the page for that site shortly after the first proxy is
requested from that source.

## Settings
Environment variables stored in redis.  These are populated on deploy from
config/default_settings.yml.
- success_ratio_threshold
  - Each proxy is periodically evaluated for its ability to be used on each
  site.  If the success_count/(success_count+failure_count) is less than this
  number, then the proxy may be decommissioned.
- default_retry_interval
  - How long to tell clients to wait for proxies to be created when we have
  none.
- server_retry_timeout
  - How long to wait for newly provisioned proxies to be ready before giving up.
  - These proxies aren't lost forever.  They can be reclaimed by the system
  later.
- proxy_age_timeout_seconds
  - If proxies haven't been requested for a site in this many seconds then
  the site forgets that it had ever used the proxies that are presently
  allocated to it.
  - If there are no more sites presently reserving these proxies then the
  proxies are decommissioned.
- failure_threshold
  - If this many failures happen in between runs of the periodic performance
  analyzer then evaluate this proxy's performance early.
  - If the number of successes is too low then the proxy will be removed from
  the site's proxy pool, and possibly decommissioned.

## API Keys
API keys can be created or destroyed.  Use the key in the api_key parameter
with the API.

# Installation and deploy instructions

Before you deploy to production you'll need to create a development environment.
Your development environment will require some of the same steps as deploying
to production, but you only need to install the core apt-get dependencies,
configure redis and rvm.  From there, run:
```
rvm install ruby2.2.0
rvm use ruby2.2.0@zartan --create
```
git clone [.]
```
cd zartan
gem install bundler
bundle install
```
Create and modify the
[config files](#config-files) for development.  Run `bundle exec rails s` to
start the rails server, and `QUEUE=* rake environment resque:work` to start
a resque worker.

Zartan is a rails application which relies on a database, redis, resque and
resque-scheduler.  The initial deployment of zartan runs on an ubuntu server,
uses a postgres database, nginx/unicorn to run the rack workers and uses monit
for process monitoring.  The database
can be easily changed in config/database.yml.  The deployment
procedure assumes that monit is being used for process monitoring, but monit
is not required to actually run zartan.  The deployment procedure could be
changed to use some other process monitoring service if necessary.

The rest of the installation instructions will assume the above configuration
unless otherwise specified.

1. Initial setup. On the target machine, as "superuser":
```
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  postgresql \
  redis-server \
  nginx \
  git-core \
  libpq-dev \
  libsqlite3-dev \
  zlib1g-dev
```
2. Configure postgres for the `zartan` database user.  Modify as necessary for
your configuration.
```
sudo -u postgres psql <<SETUP
CREATE USER root;
CREATE USER zartan LOGIN PASSWORD 'zartan';
CREATE DATABASE root OWNER root;
CREATE DATABASE zartan OWNER zartan;
SETUP
```
3. Create a `zartan` user on the Linux OS.  This can be different from the
user created in postgres.  Substitute as necessary if you use a different user,
or skip if the user is already created.
```
sudo adduser zartan
# Add with some default password
sudo vim /etc/ssh/ssh_config
# replace the line
#     #   PasswordAuthentication yes
# with the line
#         PasswordAuthentication no
sudo service ssh restart
```
4. Create the base directory for the zartan application
```
sudo mkdir -p /var/www/zartan
sudo chown zartan:zartan /var/www/zartan
```
5. Log in to linux as the application user (zartan in this case).
6. Install rvm.  Note, these instructions install rvm on a user level.
Rvm can also be installed for all users by the superuser.  See the
[RVM installation instructions](https://rvm.io/rvm/install#installation)
for how to do this.
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable
source "$HOME/.rvm/scripts/rvm"
rvm install 2.2.0
```
7. Config files
config/deploy.rb` contains a list of `:linked_files.  Each of these files
has a `file_name.sample` file in the repository.  Copy and edit these files
as appropriate, and put it in the config directory created by these
instructions:
```
zartan_root=/var/www/zartan
mkdir -p $zartan_root/shared/{config,pids,log}
```
  1. config/database.yml
  Fill in the 'production' area with the credentials for your production
  database.  The development section can remain as is for testing in dev.

  2. config/redis.yml
  The sample file can be used as-is if redis is installed
  on the same server as the web app with the default port.

  3. config/secrets.yml
  Run `rake secret` in development and put that value in production's
  `secret_key_base` section.

  4. config/unicorn.rb
  You can mostly use the sample file as-is, unless you use a different Linux
  username.

  5. config/google_omniauth.yml
  Zartan uses Google oauth to authenticate users to the admin UI.  This file
  allows google to perform this authentication.
  This file needs modification in both development and production.  To create
  `google_client_id` and `google_client_secret` fields, create [Google oauth
  2.0 credentials]
  (https://developers.google.com/youtube/registering_an_application).
  Set the redirect uri to http://HOSTNAME/auth/google_oauth2/callback.
  You can set the HOSTNAME to localhost for development and use the same
  key/secret among your developers so long as they all use the same ports.

  6. config/resque_schedule.yml
  The sample file can be used as-is, but it can be modified if any schedules
  need to be tweaked.

  7. config/default_settings.yml
  The default environment variables.  These can be modified later in the
  admin panel under the "Settings" tab.  The `allowed_domains` setting must
  be filled in with your domain which is hosted by google.com.

8. Create an ssh key for the server to pull the source code from github
```
ssh-keygen
cat ~/.ssh/id_rsa.pub
# Copy the key and add it to your github fork of the Zartan repo as a deploy key
```
9. Create config/deploy/production.rb in your dev environment.  Like the
other config files, this has a `.sample` file, but does not get uploaded
to the production server unlike the other files.

10. Initial Deploy. In the dev environment:
```
# may require "bundle exec" depending on your setup
cap production deploy --trace
```
This step succeeds if the final step complains about monit not being installed.
We couldn't install monit before now because it depends on files created by
the initial deploy.  For now, launch the various services manually and install
monit once everything is working.

11. First Launch. On the target machine, as "superuser":
Add executable init scripts for unicorn, resque_scheduler and resque_pool to
/etc/init.d. Sample files are located in config/samples/init.d.  These files
will work as-is if your application's linux username is `zartan` and rvm was
installed by the `zartan` user (not the superuser).  Change the `USER` in each
of the files if the `USER` is not zartan, and change the final `PATH` directory
to `/usr/local/rvm/wrappers/ruby-2.2.0@zartan` if rvm was installed by the
superuser.
```
sudo service zartan_unicorn start
sudo service zartan_resque_pool start
# Verify that unicorn and resque processes are running
ps -ef | egrep 'unicorn|resque'
```

12. Set up nginx.
Copy the config file in config/samples/nginx/zartan to
`/etc/nginx/sites-enabled/zartan` on the target machine.  This file should
work as-is as long as you're serving your application on the default http port
80.
```
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/zartan /etc/nginx/sites-enabled/zartan
sudo service nginx restart
# Verify that the application is being served on port 80
```

11. Install monit
```
sudo apt-get install -y monit
```
Add the monit config.  A sample file is located in
config/samples/monit/monitrc.  This file will probably require modification if
You've modified any of the other config files.  Things to check for are the
`zartan` username, the port that nginx is serving your application and the
port for redis.
```
sudo service monit reload
# Verify that monit is running and monitoring the relevant processes
sudo monit status
```

12. Optional validation. In the dev environment:
```
cap production deploy --trace
```
Check to see that the deploy process correctly detected monit running and
restarted it (this should be the last operation it performed). If you like, ssh
into the target machine and tunnel 2812:localhost:2812, then log in to the
monit web interface. From here, you can check that the
uptime of unicorn and resque_pool is small (i.e., that they were restarted by
the deploy process).

13. Where to go from here
You'll need to create one or more `Source` objects in the admin panel.  Once
you have a single `Source` you can make your first API request to get a proxy.
That will create a `Site` object visible on the admin panel.  The first request
will fail, but if you go to http://HOSTNAME/resque_web then you should see
a job to partition your first proxies.  If your first source is DigitalOcean
then zartan will not automatically detect/use the proxy you based your image
off of.  To add it manually, go to the rails console and run
`Source.first.send(:add_proxy, PROXY_IP, PROXY_PORT)`.  Other sources may
have similar requirements.

# Technical details
Operation and maintenance of zartan requires ruby programming knowledge.
It's expected that the number of Source classes will grow over time.  If
there's a proxy source that isn't part of Zartan yet then it can be added.
If the new proxy source is a cloud services provider then the `fog` gem probably
has an adapter for it.  If so, inherit your new class from `Sources::Fog`.
If not then inherit from `Source`.
Be sure to add your new class to `lib/zartan/source_type.rb`.  This allows
the admin panel to create new Source objects of this type and creates a resque
queue for that Source type on the next deploy.

The steady-state operation of zartan should be that all of your proxies
successfully scrape your target site.  In this case, the `Site` object will
be doing most of the work.  Proxies are retrieved off of a redis set sorted by
last accessed time.  This access time is updated every time the proxy is given
to the client or whenever the client informs zartan that the proxy succeeded
or failed a scrape.  Zartan always gives its clients the least recently used
proxy.  The longer a proxy goes without scraping a site the less likely it is
that site will blacklist the proxy.  These redis sorted sets
exist for every site, meaning that a proxy may have been recently used by
site \#1, but is available for site \#2.

The `Jobs::GlobalPerformanceAnalyzer` resque job runs every 15 minutes by
default.  It checks every proxy/site combination to determine if the proxy
is healthy enough to continue scraping that site.  The `success_ratio_threshold`
and `failure_threshold` settings are used to determine whether we should remove
the proxy from this site.  Note that the proxy will stay on the site even if
there is a 100% failure rate if `Site#large_enough_sample?` fails.

The `Jobs::TargetedPerformanceAnalyzer` resque job get triggered whenever a
proxy reaches `failure_threshold` failures before the global performance
analyzer resets its success/failure counts.  If there are not enough successes
to justify the proxy's existence then it is removed from the site.  Note that
we do not check to see if there are enough successes + failures because
otherwise 100% failing proxies will likely never get deleted.

If a proxy is removed from a site, then the `ProxyPerformance` object which
joins the `Proxy` with the `Site` is soft-deleted.  This proxy may not be
affiliated with this site again unless the proxy is decommissioned and happens
to be re-created with the same IP address and port.
A proxy is decommissioned by the `Source` object if no `Site` objects
are using that proxy.  If the number of proxies
available to the site drops below `min_proxies`, then more proxies are retrieved
from the database if available, else more get provisioned by the `Source`
objects.

The global performance analyzer can also cause a site to forget about all its
proxies if no proxy has been used in `proxy_age_timeout_seconds` seconds.
Unlike other methods of removing a proxy from a site, this method allows the
proxies to be used by the site if a later request comes in.  If these proxies
are not freed then they cannot be decommissioned even if the proxies fail on
all other sites.  Proxys will still be decommissioned if this `Site` is the last
to use them.

The `Jobs::SitePerformanceAnalyzer` only gets run when a proxy is requested for
a site when there are no proxies available for the site.  Proxies are added to
the site if any are available.  If not then more proxies are created.

The clients of zartan should always provide an older_than parameter to the GET
API.  If your clients frequently have to wait for a proxy, but in less time
than the older_than parameter that they request, then you have your number of
proxies and number of scraper workers tuned well.  Tune the number of proxies,
number of scraper workers and `older_than` parameter based upon how quickly you
need your scraping done against your risk levels for getting blacklisted.
