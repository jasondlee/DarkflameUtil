# DarkflameServer Util

The [DarkflameServer](https://github.com/DarkflameUniverse/DarkflameServer) is a recreation of long-discontinued LEGO Universe MMO, and is a truly impressive work. What this ulitity will do is make the installation of a server much simpler, and mostly hands-off.

Specifically, this script will:

* Add missing build packages (python3, gcc-g++, git, etc)
* Clone the DarkflameServer, AccountManager, and lcdr-utils projects
* Download a copy of the client, and navmeshes.zip
* Extract the needed files from the client
* Create and update the MySQL/MariaDB and SQList databases
* Create the admin user for the server
* Configure the AccountManager
* Modify the client to point at the server that was just built.

Once script finishes, you will be read to start the server via the `MasterServer` command, and the AccountManager by running `python app.py`. Given that these two commands are blocking, the script will not run them for you.

The scripts well for me, but if there are issues, PRs are always welcome.