## Hyperion block gap filler

### Installation

As root, install these two packages by running the following commands:

* apt install jq
* apt install python3-venv

Then as the user that runs your Hyperion installation (I use something other than root) run the setup.sh script:

* cd ~/hyperion-history-api/scripts/fill-gap
* ./setup.sh

### Using this

Now, this is going to take some work on your part.
Here's a brief overview of the included files:
- example.config.json.314  
A copy of the example.config.json file included with Hyperion 3.1.4
- example.config.json.335  
A copy of the example.config.json file included with Hyperion 3.3.5
- fill-gap.sh  
A script that will fill the first found gap in your Hyperion block index.  It does this by running
the script run-find-misssing.sh followed by set-fillgap.sh followed by indexer-start.sh.
It tries to monitor for when the index process has stopped but does a miserable job of this.
What is needed is a script/program that can query the rabbitmq-server queues to see when the
block queues are empty.  You should not try to fill a gap if there are existing messages in any
of the block queues.  Strange things happen.
- find-missing-blocks.py  
A python3 script that will find the first existing gap in your Hyperion block index.  It prints out:  
Gap:first-missing-block:next-existing-block  
where first-missing-block is the block number of the first block found missing and the next-existing-block is
the block number of the next existing block after the first missing one.  So - these equate to the values needed
for the start_on and stop_on settings in the hyperion config file.
- indexer-start.sh.example  
This is an example script to start running an indexer that uses the modified config file.  Look at the file,
copy it to indexer-start.sh and change the indicated lines (inside the example script) to do this for your Hyperion
installation.
- README.md  
This file.
- repeat.sh  
Takes a count value as a parameter (numeric) and runs fillgap.sh that many times.
- run-find-missing.sh  
A script that parses your connections.json file and runs the find-missing-blocks.py program with the appropriate paramters.
- set-fillgap.sh  
A script that given a start block number for a gap and an end block number for a gap will edit a config.json file
and put those values in for the start_on and stop_on settings.
- setup.sh  
Does the necessary python3 environment setup and install of the elasticsearch and packaging packages using pip.
- waxmain-fillgap.config.json.tmpl
- waxtest-fillgap.config.json.tmpl  
These two files are what I use for doing the fillgap work.  They are pretty barebones and the intent is that they
get an indexer running that will put the blocks indicated by start_on and stop_on in the config file onto the
block queue for the actual indexer to process.

### Caveats

Many, I'm sure.  I run this on a standalone server that does not run an actual indexer.  That runs on
a different server.
What this really needs is to be integrated into the base Hyperion repo.  I will work with Igor and/or the
Rio team to accomplish this.
I've used this for both Hyperion 3.1.4 and 3.3.5, and also for various ElasticSearch versions include 7.x and 8.0.
It works well for me - and obviously your mileage may vary (someone please tell me a good European verstion of
that phrase).
