#!/bin/bash
DIR=/home/cloudfilesupdater/cloud-loader
PATH=$PATH:/usr/local/bin/

REPOS[0]=somedir/pages
REPOS[1]=someOtherDirectory

TARGETDIR[0]=acontainer
TARGETDIR[1]=anothercontainer

k=0
for i in ${REPOS[@]}
do
	  OUTPUT=`cd /home/cloudfilesupdater/cloud-loader/${REPOS[$k]}/ && git pull`
		  if [[ $OUTPUT != "Already up-to-date." ]]; then
						cd ${DIR} && ./node_modules/coffee-script/bin/coffee cloud-loader.coffee -x ${TARGETDIR[$k]} ${REPOS[$k]}
						  fi
							k=`expr $k + 1`
						done
