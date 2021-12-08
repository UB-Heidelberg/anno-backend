# anno-backend-ubhd

> Setup of [anno](https://github.com/kba/anno) for a server with MongoDB backend

This repo contains no code but the configuration files and scripts to deploy
and run a [Web Annotation Protocol Server](https://www.w3.org/TR/annotation-protocol/)
with a [few extensions](https://github.com/kba/anno#concepts).

It uses [Production Process Manager](https://github.com/Unitech/pm2) to deploy
and scale the service.

<!-- BEGIN-MARKDOWN-TOC -->
* [Setup](#setup)
	* [Node.JS](#nodejs)
	* [Repositories](#repositories)
	* [Install dependencies](#install-dependencies)
	* [Test the setup](#test-the-setup)
	* [Running productively](#running-productively)
* [Configuration](#configuration)
	* [Collections](#collections)
		* [`secret`](#secret)
		* [`purlTemplate`](#purltemplate)
		* [`metadataEndpoint`](#metadataendpoint)
	* [Users](#users)
		* [`public`](#public)
		* [`public.displayName`](#publicdisplayname)
		* [`public.icon`](#publicicon)
		* [`alias`](#alias)
		* [`role`](#role)
		* [`rules`](#rules)
		* [Example user](#example-user)
	* [ACL](#acl)
* [Troubleshooting](#troubleshooting)
	* [NOSPC error](#nospc-error)

<!-- END-MARKDOWN-TOC -->

## Setup

The service requires [Node.JS](https://github.com/nodejs/node) version 7 or up
and npm to install dependencies. All libraries and software related to running
this service will be installed in the local `./node_modules` folder.

For data storage, this service requires access to a MongoDB NoSQL database.
MongoDB is available in virtually all Linux distributions.

For setting up and running tasks you will also need:

* git
* make
* tar
* gzip
* mongodump, mongorestore (in Debian/Ubuntu: package `mongodb-clients`)

### Node.JS

We recommend using the [Node Version Manager](https://github.com/creationix/nvm) to install Node.JS.

We advise against using the Node.JS/npm versions provided by OS vendors since
these are often out-of-date.

### Repositories

Make sure that the `anno` monorepo is located at `./anno-common`.

If you do not have strong opinion on which anno-common you want to use and
how to obtain it, we recommend you symlink (see below) the one declared as
a submodule. It should always point to the latest known-good (compatible)
version suitable for this version of anno-backend.

To install the symlink:

```sh
ln --symbolic --no-target-directory -- anno-common.known-good anno-common
```

You can initialize the submodule(s) after shallow (non-recursive) clone with

```sh
git submodule update --init --recursive
```

Otherwise, clone the repository recursively from Github:

```sh
git clone --recursive https://github.com/kba/anno anno-common
```


### Install dependencies

(Unless specified otherwise, all commands are to be run in the root of this repository, the same directory as this README)

```sh
make install
```

This will:

* Setup all sub-projects of anno-common
* Install repo-local dependencies (`pm2`)
* Set up symlinks

### Test the setup

To run a basic server w/o any authentication or support for users and access
rules, see the [`./pm2.test.yml`](./pm2.test.yml) configuration file.

```
./node_modules/.bin/pm2 --no-daemon start pm2.test.yml
```

This should start a server on port `33321` that will not use a MongoDB
collection but a flat file for storage, without authentication or ACL.

Note how all configuration is done using environment variables. You could also
set those variables in your shell or from a script and run the server directly.

### Running productively

See [`pm2.prod.yml`](./pm2.prod.yml):

* Use the [MongoDB backend](https://github.com/kba/anno/tree/master/anno-store-mongodb) for data storage (`ANNO_STORE='@kba/anno-store-mongodb'`)
* Provide a [Shibboleth-based authentication service](https://github.com/kba/anno/blob/master/anno-server/routes/auth-shibboleth.js) (`ANNO_SERVER_AUTH='shibboleth'`)
* Load the collection configuration from file for every HTTP request (`ANNO_MIDDLEWARE_PLUGINS='@kba/anno-plugins:PreCollectionFile'`)
* Before every store operation (`ANNO_STORE_HOOKS_PRE`):
  * Replace the `user` passed in the context with the user in the user file, if found (`@kba/anno-plugins:PreUserFile`)
  * Replace the `creator` of every annotation found with the user in the user file, if found (`@kba/anno-plugins:CreatorInjectorFile`)
  * Apply the [access control rules](https://github.com/kba/anno/tree/master/anno-plugins) against the context (`@kba/anno-plugins:PreAclFile`)
* After every store operation (`ANNO_STORE_HOOKS_POST`):
  * Replace the `creator` of every annotation found with the user in the user file, if found (`@kba/anno-plugins:CreatorInjectorFile`)

When running productively, create a dedicated user for the annotation system (e.g. `anno`).

Then setup pm2 to start with your init system.

As the annotation user, run `pm2 startup`, you should get output like this:

```
[PM2] Init System found: systemd
[PM2] You have to run this command as root. Execute the following command:
sudo env PATH=$PATH:/usr/bin /home/anno/build/github.com/anno/anno/anno-server/node_modules/pm2/bin/pm2 startup systemd -u anno --hp /home/anno
```

Running this sudo command will setup a unit file for a service running pm2 for
the anno user. It should restart when the system is rebooted


### Run with init system daemon

## Configuration

Basic configuration is done using environment variables. More complex data such
as users, collections and access rules can be placed in files.

### Collections

Collections can be defined either statically or in a JSON or YAML file (must end in `.json` or `.yaml` resp.).

The default collection is named `default`.

A collection is a distinct set of annotations with its own configuration. You
could use separate collections for separate services or authentication realms.

#### `secret`

`secret` is a private key to be used for signing JSON Web Tokens when using access control.

#### `purlTemplate`

`purlTemplate` is the collection-specific pattern of deriving a persistent,
nice, URL from an annotation.

If `purlTemplate` is not defined, no redirection will happen.

The syntax for interpolation is [mustache](https://mustache.github.io/), i.e.
variable names in double brackets, padded by a single space: `{{ variableName }}`.

You can use the following variables:

* `annoId`: The URL of the annotation
* `slug`: The identifier of the annotation, i.e. the last URL segment
* `targetId`: Determine the target of the annotation, using the algorithm in [anno-queries](https://github.com/kba/anno/tree/master/anno-queries#targetid)

#### `metadataEndpoint`

`metadataEndpoint` is the URL from which metadata can be gathered about this
collection. This is necessary for ACL rules based on target-specific metadata.

### Users

Users can be defined either statically or in a JSON or YAML file (must end in `.json` or `.yaml` resp.).

There is no default user.

Users are key-value pairs, where the key is the primary ID as provided by an
authentication backend (the `user` element in the context). But see [`alias`](#alias) for additional IDs.


#### `public`

`public` is the data about a user that is supposed to be publicly visible. With
the `CreatorInjector` plugin, the creator of annotations is replaced with this
information.

See [anno-frontend](https://github.com/kba/anno-frontend) for how this
information is used.

#### `public.displayName`

`displayName` is the name as it is supposed to be displayed in the browser.

#### `public.icon`

`icon` is the URL of an avatar to be displayed next to the name. You could use a gravatar-URL here.

#### `alias`

`alias` contains additional IDs for this user, e.g. if users from different
authentication realms are to be mapped to the same user.

Can be an array or a string.

#### `role`

`role` is the role of the user, corresponding to the roles defined in the [access control rules](#acl)

**NOTE**: If `role` is set globally in the user config, it will be the default. It is strongly recommended to set the `role` in the [`rules`](#rules)

#### `rules`

`rules` is an array of rules.

A rule is an ordered pair of *condition* and *result*.

*condition* is a query on the context of the store operation, in the syntax of a Mongo/sift.js query.

*result* is an object to partially override the user configuration **if *condition* is met**.

E.g. The rule `[{collection: 'foo'}, {role: 'bar'}]` will match only for
requests on the `foo` collection and in these cases will set the role of the
particular user to `bar`.

#### Example user

```
'john.doe@example.com':
  alias:
    - 'https://idp.uni-heidelberg.de!https://anno.ub.uni-heidelberg.de/shibboleth!VjuYKaMOQlfT1QA7w9geTrUATmI='
  public:
    displayName: 'John Doe'
    icon: 'https://gitlab.ub.uni-heidelberg.de/uploads/system/user/avatar/17/avatar.png'
  rules:
    - [{collection: 'default'}, {role: 'creator'}]
    - [{collection: 'ebooks'}, {role: 'moderator', public.displayName: 'John D. (Moderator)`}]
```

### ACL

ACL (access control list) rules are an array of ACL rules.

An ACL rule is a *condition*-*result*-*description* triple.

The *description* is optional and mostly for debugging and self-documentation.

The *condition* is applied to the context for **every operation**. As with
[user rules](#rules) the syntax is the same as in Mongo/sift.js queries. See
[sift-rule](https://github.com/kba/sift-rule) for rule mechanics.

The *result* is a boolean value:

* `true` or any other truthy value: The operation shall continue
* `false`, `undefined` or `0`: The operation shall not continue

## Deploy

We recommend to run the server locally with a high port number and proxy
outside traffic through a webserver like Apache httpd or nginx.

We recommend to run the annotation server in its own subdomain like
`anno.yourhost.net`.

### Apache

Let's assume:

* The [anno-backend](https://github.com/kba/anno-backend) repository has been
  cloned to `/usr/local/anno-backend`
* You want to deploy the annotation server on `anno.example.org` The annotation
* route (i.e. the [Web Annotation Protocol](https://www.w3.org/TR/annotation-protocol/)-conformant
  part) is to run at `http://anno.example.org/anno`

Add this to your Apache configuration:

```apache
<VirtualHost anno.example.org:80>

  ServerName anno.example.org
  DocumentRoot /usr/local/anno-backend/dist

  <Location /anno>
  ProxyPass http://localhost:3000 retry=0
  </Location>

</VirtualHost>
```

Set up `pm2.prod.yml` to match the host, e.g.

```yaml
    # ...
    env:
      # ...
      ANNO_OPENAPI_HOST: "anno.example.org"
      ANNO_OPENAPI_BASEPATH: "/anno"
      ANNO_BASE_URL: 'https://anno.example.org'
      ANNO_BASE_PATH: '/anno'
```

Start the server:

```sh
make start
```

## Troubleshooting

### NOSPC error

```sh
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```
