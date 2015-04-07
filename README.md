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
them to your web scraper through a RESTful API.  Zartan will maintain seperate
pools of proxies for each website you scrape, allowing you to use the same
proxies to scrape multiple sites, even if specific proxies have been banned
on specific sites.

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
speccified site

## Report proxy failure
```
PUT http://HOST_NAME/v1/SITE_NAME/11/failed
```
Informs zartan that the proxy with id #11 failed to scrape a page.
In the short term, this resets the proxy's idle time.  In the long term,
this is used to evaluate whether the proxy is still able to scrape the
speccified site.

# Admin panel
The admin panel uses google OAUTH to authenticate.  If google manages your
email then authentication simply requires whitelisting your email domain in
`config/default_settings.yml`.

## Sites
A Zartan Site represents which website you're targeting with your scrapers.
Zartan needs to know what site the proxy is being used to scrape so that it
can keep track of which proxies have been banned on which sites.

### Configuration
- min_proxies
  - If there are fewer than this many proxies available for this site then
  zartan will try to provision more
- max_proxies
  - The maximum number of proxies to request/provision for the site.

## Sources
A Zartan Source is a proxy provider.  Typically this will be a cloud services
provider, but it could be any external entity capable of providing http proxies.
Creating a Source object requires an account with that provider.  If that
provider is a cloud services provider, then you are responsible for creating
the initial image of that proxy.  We recommend creating the smallest server
allowed and installing tiny_proxy on it.

Cloud service providers will typically allow you to create servers in multiple
geographic regions.  If you want proxies from multiple regions, then create 3
Source objects with the same API/login credentials, but different regions.

### Configuration
- Type
  - There can be many different types of Sources.  Typically this is
  a cloud services provider.  Creating a new Type requires subclassing the
  `Source` model.
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
`config/default_settings.yml`.
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
  - If it is the only site presently reserving these proxies then the proxies
  are decommissioned.
- failure_threshold
  - If this many failures happen in between runs of the periodic performance
  analyzer then evaluate this proxy's performance early.
  - If the number of successes is too low then the proxy will be removed from
  the site's proxy pool, and possibly decommissioned.

## API Keys
API keys can be created or destroyed.  Use the key in the api_key parameter
in the API.

# Installation and deploy instructions
Zartan is a rails application which relies on a database, redis, resque and
resque-scheduler.  The initial deployment of zartan runs on an ubuntu server,
uses a postgres database, nginx/unicorn to run the rack workers and uses monit
for process monitoring.  The database
can be easily changed in `config/database.yml`.  The deployment
procedure assumes that monit is being used for process monitoring, but monit
is not required to actually run zartan.  The deployment procedure could be
changed to use some other process monitoring service if necessary.

The rest of the installation instructions will assume the above configuration
unless otherwise specified.

Note: several steps of this process will refer to yml files in the `config`
directory.  Most of these files have `config/file_name.yml.sample` files which
provide a basic skeleton of what each file should look like.

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
your configuration.  Make sure these parameters are reflected in
`config/database.yml`.
```
sudo -u postgres psql <<SETUP
CREATE USER root;
CREATE USER zartan LOGIN PASSWORD 'zartan';
CREATE DATABASE root OWNER root;
CREATE DATABASE zartan OWNER zartan;
SETUP
```
3. Create a `zartan` user on the Linux OS.  This can be different from the
user created in postgres.  Substitute as necessary if you use a different user
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
5. Log in to linux application user (zartan in this case)
6. Install rvm.  Note, these instructions install rvm on a user level.
Rvm can also be installed for all users by the superuser.  See RVM installation
instructions for how to do this.  In that case, modify the relevant init.d
scripts to add the correct ruby directory to PATH.
```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable
source "$HOME/.rvm/scripts/rvm"
rvm install 2.2.0
```
7. `config/deploy.rb` contains a list of `:linked_files`.  Each of these files
has a `file_name.sample` file in the repository.  Copy and edit these files
as appropriate, and put it in the config directory created by these
instructions:
```
zartan_root=/var/www/zartan
mkdir -p $zartan_root/shared/{config,pids,log}
```
8. Create an ssh key for the server to pull the source code from github
```
ssh-keygen
cat ~/.ssh/id_rsa.pub
# Copy the key and add it to your fork of the Zartan repo as a deploy key
```
9. From your development environment:
  1. Create a `config/deploy/production.rb` in your dev environment.  Like the
  other config files, this has a `.sample` file, but does not get uploaded
  to the production server unlike the other files.