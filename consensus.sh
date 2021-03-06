#!/usr/bin/env bash

######################################################################
#Copyright (C) 2015, Battelle National Biodefense Institute (BNBI);
#all rights reserved. Authored by: Sergey Koren
#
#This Software was prepared for the Department of Homeland Security
#(DHS) by the Battelle National Biodefense Institute, LLC (BNBI) as
#part of contract HSHQDC-07-C-00020 to manage and operate the National
#Biodefense Analysis and Countermeasures Center (NBACC), a Federally
#Funded Research and Development Center.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are
#met:
#
#* Redistributions of source code must retain the above copyright
#  notice, this list of conditions and the following disclaimer.
#
#* Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#
#* Neither the name of the Battelle National Biodefense Institute nor
#  the names of its contributors may be used to endorse or promote
#  products derived from this software without specific prior written
#  permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
######################################################################

SCRIPT_PATH=`cat scripts`

LD_ADDITION=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#"  |grep LD_LIBRARY_PATH |wc -l`
if [ $LD_ADDITION -eq 1 ]; then
   LD_ADDITION=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#"  |grep LD_LIBRARY_PATH |tail -n 1 |awk '{print $NF}'`
   export LD_LIBRARY_PATH=$LD_ADDITION:$LD_LIBRARY_PATH
fi
VARIANTPARAMS=`cat smrtparams`

wrk=`pwd`
syst=`uname -s`
arch=`uname -m`
name=`uname -n`

if [ "$arch" = "x86_64" ] ; then
  arch="amd64"
fi

jobid=$SGE_TASK_ID
if [ x$jobid = x -o x$jobid = xundefined -o x$jobid = x0 ]; then
jobid=$1
fi

if test x$jobid = x; then
  echo Error: I need SGE_TASK_ID set, or a job index on the command line
  exit 1
fi

prefix=`cat prefix`
reference=`cat reference`
asm=`ls $reference/sequence/*.fasta |awk '{print $1}'`
ploidy=`cat $reference/reference.info.xml |grep ploidy |awk -F ">" '{print $2}' |awk -F "<" '{print $1}'`
DIPLOID=""
if [ $ploidy == "haploid" ]; then
   DIPLOID=""
elif [ $ploidy == "diploid" ]; then
   DIPLOID="" # --diploid "
else
   echo "Invalid ploidy $ploidy"
   exit 1
fi
echo "Running with $prefix $asm"
echo "$VARIANTPARAMS $SCRIPT_PATH $DIPLOID"

#rm -rf $prefix.$jobid.byCtg
if [ -e "$prefix.$jobid.fasta" ]; then
   echo "Already done!"
   exit
fi

if [ ! -e "$prefix.$jobid.byContig.cmp.h5" ]; then
   echo "Invalid job id $jobid, exiting"
else
   if [ ! -e "$prefix.$jobid.fasta" ]; then
   
      # fix bad load command
      if [ -e "$jobid.out" ]; then
        NUM_ERROR=`cat $jobid.out |grep IOError |grep bax |wc -l`
        if [ $NUM_ERROR -ge 1 ]; then
           echo "Need to reload for $jobid"
           loadChemistry.py `pwd`/$prefix.bax.fofn $prefix.$jobid.byContig.cmp.h5
        fi
      fi

      rm -f $prefix.$jobid.cmp.h5
      variantCaller.py --skipUnrecognizedContigs -W $prefix.$jobid.contig_ids  $DIPLOID -x 5 -q 40 -P$VARIANTPARAMS -v -j8 --algorithm=quiver $prefix.$jobid.byContig.cmp.h5 -r $asm -o $prefix.$jobid.gff -o $prefix.$jobid.fastq -o $prefix.$jobid.fasta

      if [ -e "$prefix.$jobid.fasta" ]; then
         numExpected=`cat $prefix.$jobid.contig_ids |wc -l |awk '{print $1}'`
         numActual=`cat $prefix.$jobid.fasta |grep ">"|wc -l |awk '{print $1}'`
         if [ $numActual -eq $numExpected ]; then
            echo "Safe to remove"
            rm $prefix.$jobid.byContig.cmp.h5
         fi
      fi
   fi
fi
