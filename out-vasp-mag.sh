
outfile1="all-energy.txt"
TEMP4_mag="all-mag-temp4.txt"
outfile1_sub_mag="all-mag.txt"
outfile2_magnetization="all-magnetization.txt"
outfile3_magnetization_ncol="all-magnetization_ncol.txt"

rm -f TEMP*
rm -f $outfile1
rm -f $outfile1_sub_mag
rm -f $outfile2_magnetization
rm -f $outfile3_magnetization_ncol
#rm -f list_ispin

printf 'Name                                                                  Result                     Cycles    Time           Symm   KPOINTS          TOTEN/eV            Volume    ' >> $outfile1
echo 'Name                                                                  Magnetizations_of_ions...' >> $outfile1
echo 'Name                                                                  Magnetizations_of_ions...' >> $outfile1_sub_mag

curdir=$(pwd)

#zamiast żeby szedł linuxowo po folderach, żeby był porządek jak w WinSCP
#START
#list=$(ls -1v) #jednak one nie mają "/" więc sprawdzam, czy są folderami
#ls --color=no -1v > list #sortuje bez koloru (ma wartości typu 01 zmieniające wszystko) + dodaje plik
ls --color=no -h > list #sortuje bez koloru (ma wartości typu 01 zmieniające wszystko) + dodaje plik

#LC_ALL=C sort -k 1.1f,1.1  -o list list  #sortuje plik z uppercase tak samo jak lowercase + output ten sam plik

#for dir in ./list; do
while read dir; do
if [ -d "$dir" ]; then

 #usuwanie ostatniego znaku "/"
 #dir=${dir%*/}
 
 
 #jeśli poprzedni folder był podobny z nazwy (bez backup) to nie robi linii
 #if ! [[ $dir == "$last_dir"*  ]]; then
 # echo '------------------------------------------------------' >> $outfile1
 # echo 'name                                    result           cycles    time           KPOINTS          TOTEN/eV            Volume' >> $outfile1
 #fi
 #last_dir=$(echo $dir)  
 #if [[ $dir == *"backup"* ]]; then
 # last_dir=${dir:: -9}
 #fi
 
#SIMPLE
 if [[ $dir == *"backup"* ]]; then
  printf 'omit '$dir'\n'
 elif [ -e $dir/OUTCAR ]; then
 
 #SLURM_JOB_ID = 5844924
 #sprawdza czy jest plik outputowy; jak tak to bierze queue_id jak nie 
  if ls $dir/slurm* 1>/dev/null 2>/dev/null ; then
   queue_id=$( echo $dir/*.out | rev | cut -d- -f1 | rev | cut -d. -f1 )
   #queue_id=$( grep 'SLURM_JOB_ID' $dir/slurm*out | cut -d' ' -f3 | head -1 ) 
  elif [ -e $dir/*.out ]; then
   queue_id=$( grep 'SLURM_JOB_ID' $dir/*.out | cut -d' ' -f3 | head -1 ) 
  elif ls $dir  | grep -q -E '^[0-9]+$'; then
   queue_id=$( ls $dir  | grep -E '^[0-9]+$' )
  else 
   queue_id='unknown'
  fi
  #echo $queue_id
  
  rm -f $dir/*.vasp
  
  #czy jest CONTCAR, kopiuje jego pod nazwę
  if [ -e $dir/CONTCAR ]; then
   echo ${dir##*/}
   cp $dir/CONTCAR $dir/$dir-CONTCAR.vasp
  fi
  
  #czy jest POSCAR
  if [ -e $dir/POSCAR ]; then
   cp $dir/POSCAR $dir/$dir-POSCAR.vasp
  fi
  
  #czy jest OUTCAR
  if [ -e $dir/OUTCAR ]; then
   printf %-70s  $dir' ' >> $outfile1
   
     #errors
	 words='warning error incompat'
	 if ls $dir/slurm* 1>/dev/null 2>/dev/null ; then
	   if grep -E -q -i 'warning|error|incompat' $dir/*out ; then
	    for w in $words; do
	     if grep -q "stress and forces are not correct" $dir/*out; then
	      printf %-9s ' ' >> $outfile1
		  break
	     elif grep -q -i $w $dir/*out; then
		  #printf $w >> $outfile1
	      printf %-9s "$w" | sed -e 's/ /_/g' >> $outfile1
		  #break # jeśli wystarczy 1 error
	     fi
	    done
	   else
	     printf %-9s ' ' >> $outfile1
	   fi 
	 else 
	  printf %-9s 'no_stdout_' >> $outfile1
	 fi
	 
	 #words='warning error incompatible Supported'
	 #for w in $words; do
	 #for k in */*out; do 
	 #if grep -q -i $w $k; then
	 # #grep -i $w $k | head -1
	 # echo $k $w
	 #fi
	 #done
	 #done
	 
	 #FINISH
	 if squeue -u matdom | grep -q $queue_id; then
 	  printf %-18s $queue_id >> $outfile1
	  if [ -e $dir/*.out ]; then
	   :
	  else
	   printf %-18s 'In_queue...' >> $outfile1
	   echo >> $outfile1
	   continue 
	  fi
	 elif grep -q 'Total CPU time used' $dir/OUTCAR; then
 	  printf %-9s "Finished_" >> $outfile1
 	  #OPTIMIZATION-result
	  NELM=$(grep -a -i 'nelm ' $dir/OUTCAR | awk -F ' ' '{print $3}' | sed 's/[^0-9]*//g')
	  NELM_done=$(grep -a 'D.*:' $dir/OSZICAR  | tail -1 | awk -F ' ' '{print $2}' | sed 's/[^0-9]*//g')
 	  if ! [ "$NELM" -gt "$NELM_done" ]; then
	   printf %-9s 'NELM_lim ' >> $outfile1
	  elif grep -q 'reached required accuracy' $dir/OUTCAR; then
 	   printf %-9s 'Opt ' >> $outfile1
 	  elif grep -q 'NSW    =      0' $dir/OUTCAR; then
	   printf %-9s 'S-Point ' >> $outfile1
	  else
 	   printf %-9s 'Not-opt ' >> $outfile1
 	  fi
	 else
 	  printf %-18s 'Not_finished ' >> $outfile1
     fi
 	
 	#CYCLES
 	if grep -q 'F= ' $dir/OSZICAR; then
 	 cycles=$(grep -a 'F= ' $dir/OSZICAR | tail -1 | cut -c 1-5 | tr -d '\n' | tr -d ' ' )
 	else
 	 cycles=0
 	 #grep 'F= ' $dir/OSZICAR | tail -1 | cut -c 1-5 | tr -d '\n' >> $outfile1
 	 #printf 'cycles ' >> $outfile1
 	fi 
 	printf %-10s $cycles >> $outfile1
 		
 	#TIMING
     if grep -q 'Total CPU time used' $dir/OUTCAR; then	
 	 seconds=$(grep -a 'Elapsed time' $dir/OUTCAR | tail -1 | cut -c 45-58 | tr -d '\n' | tr -d ' ' | cut -d '.' -f 1)
 	 timestep=60
 	 minutes=$(($seconds / 60))
 	 #minutes=$(echo $seconds $timestep | awk '{printf "%4.3f\n",$1/$2}')
 	 if [ "$minutes" -gt "60" ]; then
       hours=$(($minutes / 60))
 	  minutes=$(($minutes - $hours * $timestep))
 	  else
 	  hours=0
 	 fi
 	 remainder=$(($seconds - $hours * 3600 - $minutes * 60))
 	 printf %-15s $hours'h_'$minutes'min_'$remainder's' >> $outfile1
 	elif squeue -u matdom | grep -q $queue_id; then
 	  printf %-15s $'calculating... ' >> $outfile1 
 	else
 	 printf %-15s $'time_limit_met ' >> $outfile1
 	fi
 	
	#SYMM
	 #if grep -q 'static configuration has the point symmetry' $dir/OUTCAR; then	
	 if grep -q 'point group associated with its full space group' $dir/OUTCAR; then	
	   symm=$(grep -a -i 'point group associated with its full space group' $dir/OUTCAR | tr -d '.' | awk '{print $NF}' | tail -1 )
	 elif grep -q 'All symmetrisations will be switched off' $dir/OUTCAR; then
	   symm='C_1'
	 else 
	   symm=$(grep -a -i 'static configuration has the point symmetry' $dir/OUTCAR | tr -d '.' | awk '{print $NF}' | tail -1 )
	 fi
	 printf %-7s $symm >> $outfile1
	
 	#KPOINTS
     if [ -e $dir/KPOINTS ]; then
       if grep -q 'Auto' $dir/KPOINTS ; then
	     kpoints=$(sed -n '4p' $dir/KPOINTS | sed -e 's/ /_/g' | tr -d '\n' | tr -d '\r')
	     printf %-17s $kpoints >> $outfile1
	   else 
	     printf %-17s 'Explicit_kpoints' >> $outfile1
	   fi
     elif grep -q -i 'kspacing' $dir/INCAR; then 
	   kpoints=$(grep -a -i 'kspacing' $dir/INCAR | awk -F ' ' '{print $3}' | tr -d '\n' | tr -d '\r')
       printf %-17s 'spacing='$kpoints >> $outfile1
	 else 
       kpoints=$(grep -a 'generate k-points' $dir/*.out | cut -c 25-40 | sed -e 's/ /_/g' | tr -d '\n' | tr -d '\r')
	   printf %-17s $kpoints >> $outfile1
     fi  
 	 
 	#TOTEN
      #toten=$(grep 'TOTEN  ' $dir/OUTCAR | tail -1 | cut -c 30-45 | tr -d '\n' | tr -d ' ' )
	 if grep -q -i 'toten' $dir/OUTCAR ; then
	  	 toten=$(grep -a 'TOTEN  ' $dir/OUTCAR | tail -1 | cut -c 30-45 | tr -d '\n' | tr -d ' ' | tr -d [A-Z][a-z] | tr -d [*] )
		 printf %-20s $toten >> $outfile1
	 elif grep -q -i 'fail' $dir/*out; then
	     grep -a -i -h 'fail' $dir/*out | tail -1 | sed -e 's/ /_/g' | tr -d '\n'  >> $outfile1 
	 elif grep -q -i 'error' $dir/*out; then
	     grep -a -i -h 'error' $dir/*out | tail -1 | sed -e 's/ /_/g' | tr -d '\n'  >> $outfile1 
	 fi
 	
 	#VOLUME
      volume=$(grep -a 'volume of cell :' $dir/OUTCAR | cut -c 20-31 | tail -1 | tr -d '\n'| tr -d ' ' )
      printf %-10s $volume >> $outfile1
      #printf '\n' >> $outfile1
 
 	#CHECK IF SUPERCELL or found PRIMITIVE
 	 if grep -q 'primitive cells build up' $dir/OUTCAR; then 
 	  printf %-50s  $dir >> TEMP3 
 	  printf " primitive_cell_found\n" >> TEMP3
 	 fi
     
	 rm -f $dir/CONTCAR*xsf
     #szukanie magnetization (bez backupów)
     if ! echo $dir | grep -q 'backup'; then
         #ispin_tag=$(grep -i 'ispin' $dir/INCAR | tr -d ' ' | tr -d 'ISPIN=') 
         ispin_tag=$(grep -a -i 'ISPIN' $dir/OUTCAR | cut -c 1-19 | tr -d ' ' | tr -d 'ISPIN=')
         ncol_tag=$(grep -a -i 'LNONCOLLINEAR' $dir/OUTCAR | cut -c 1-26 | tr -d ' ' | tr -d 'LNONCOLLINEAR=')
         #if grep -q 'ISPIN  =      1' $dir/OUTCAR; then
         if [[ $ispin_tag = "1" && $ncol_tag = "F" ]] ; then
         printf %-70s  $dir' '  >>  $outfile1 
		 printf  " ISPIN=1"  >>  $outfile1 		 
         printf %-70s  $dir' '  >>  $outfile1_sub_mag 
		 echo    " ISPIN=1"  >>  $outfile1_sub_mag 	 
		
		#PART FOR COLLINEAR Magnetizations_of_ions
		
	    #elif [[ $(grep -q 'ISPIN=2' list_ispin) ]] && [[ $(grep -q 'LNONCOLLINEAR =      F' $dir/OUTCAR) ]] ; then
	    #elif grep -q 'ISPIN=2' list_ispin ; then
		elif [[ $ispin_tag = "2" && $ncol_tag = "F" ]] ; then
         if grep -q 'General timing and accounting informations for this job' $dir/OUTCAR; then
           #printf %-50s  $dir >> $TEMP4_mag #PART1
           grep -a -B 800 'General timing and accounting informations for this job' $dir/OUTCAR > TEMP
		 elif grep -q -i 'magnetization (x)' $dir/OUTCAR; then
		   tail -n 1000 $dir/OUTCAR > TEMP
		 else 
		   #echo >> $outfile1_sub_mag 
		   echo >> $outfile1
		   continue
		 fi
		 printf %-70s  $dir' ' >> $TEMP4_mag  #PART2 - jeśli chcesz by dla wszystkich wypluwał magnetyzacje, wyłącz PART1
         printf %-70s  $dir' ' >> $outfile1_sub_mag  #PART2 - jeśli chcesz by dla wszystkich wypluwał magnetyzacje, wyłącz PART1
         
	       printf "$dir\n" >> $outfile2_magnetization
           if grep -q 'tot       ' TEMP; then
		    sed -n "/magnetization (x)/, /tot      /{p; /tot      /q}" TEMP | sed '1,2d' > TEMP2
	        less TEMP2 >> $outfile2_magnetization
            echo >> $outfile2_magnetization
		    sed -i '1,2d' TEMP2 ; head -n -2 TEMP2 > TEMP; mv TEMP TEMP2
		   else 
			grep -a -A4 "magnetization (x)" TEMP | tail -1  > TEMP2
		   fi
			 
		   #CONTCAR_VECTOR.xsf
		   rm -f $dir/tmp_*
           echo 'CRYSTAL' > $dir/CONTCAR.xsf
           echo 'PRIMVEC' >> $dir/CONTCAR.xsf 
           sed -n '3,5p' $dir/CONTCAR >> $dir/tmp_cell
           sed -n '3,5p' $dir/CONTCAR >> $dir/CONTCAR.xsf
           echo 'PRIMCOORD' >> $dir/CONTCAR.xsf 
           at_types=$(sed -n 6p $dir/CONTCAR )
           at_count=$(sed -n 7p $dir/CONTCAR )
           at_no=$(sed -n 7p $dir/CONTCAR | awk '{for(i=1;i<=NF;i++) t+=$i; print t;  t=0}')
           echo $at_no ' 1' >> $dir/CONTCAR.xsf  
		   #cp $dir/CONTCAR.xsf $dir/CONTCAR_rough.xsf # gdyby chcieć detail
		   counter=0
		   for p in $at_count; do
		     counter=$[$counter +1]
			 #echo $p 'p'
			 #echo $counter
			 at=$(echo $at_types | cut -d ' ' -f $counter )
			 #echo $at
		     for ((l=1;l<=$p;l++)); do
			   printf  %-5s "$at" >> $dir/tmp_at
			   echo >> $dir/tmp_at
			 done
		   done
		   
		   #problem z selected dynamics
		   if grep -q -i 'sel' $dir/CONTCAR ; then 
		    sed -n '10,$p' $dir/CONTCAR | head -n $at_no > $dir/tmp_frac_sel
			awk 'NF{NF-=3};3' < $dir/tmp_frac_sel > $dir/tmp_frac
		   else 
		    sed -n '9,$p' $dir/CONTCAR | head -n $at_no > $dir/tmp_frac
		   fi
		   #CONTCAR_VECTOR.xsf
	       
	       
	       lastline=$( tail -1 TEMP2 | head -1 )
		   number=$( echo $lastline | cut -f 1 -d ' ' )
		   #number=$( tail -1 TEMP2 | head -1 | cut -c 4-6) 
	       #echo $number
	       
           if [ -z "$number" ] ; then
		    printf "no_magnetization_in_the_OUTCAR" >> $outfile1_sub_mag 
		   else
		    for ((i=$number;i">="1;i--)); do
	           lastline2=$( tail -$i TEMP2 | head -1 )
		       if grep -q 'd       f       tot' $dir/OUTCAR; then
		         magnetization=$(echo $lastline2 |  cut -f 6 -d ' ' | tr -d '\n' ) 
		       else
		         magnetization=$(echo $lastline2 |  cut -f 5 -d ' ' | tr -d '\n' ) 
		       fi
		       LANG=C printf "%7.3f" $magnetization >> $TEMP4_mag 
		       LANG=C printf "%7.3f" $magnetization >> $outfile1_sub_mag 
			   # | bc -l  --> using Bash's numeric
			   # awk -v   --> import zmiennej środowiskowej shella
			   # if bc -l --> 1=true, 0=false
			   #echo $magnetization
			   #mag_sq=$(echo | awk -v mag="$magnetization" '{printf "%.3f ", mag^2}')
               #echo $mag_sq
			   #if [[ "$(echo "0.04 <  $mag_sq" | bc -l)" == 1 ]] ; then
               mag_abs=$(echo ${magnetization#-}) #problem bo nie było modułu liczby - wartość absolutna
			   if [[ "$(echo "0.2 <  $mag_abs" | bc -l)" == 1 ]] ; then
                 LANG=C printf "%7.3f" $magnetization >> $dir/tmp_mag_x_row
               else 
               	LANG=C printf "%7.3f" 0 >> $dir/tmp_mag_x_row
               fi
		       #printf "%7.3f\n" $magnetization | tr -d '\n' >> $TEMP4_mag 
		       #echo $magnetization
		       
		       #for ((i=1;i"<="$number;i++)); do
		       #sed -n "$i"p TEMP2 | cut -c 36-43 | tr -d '\n' >> $TEMP4_mag
		       #sed -n "$i"p TEMP2 | cut -c 36-43 | tr -d '\n' >> $TEMP4_mag
	        done
		    #CONTCAR_VECTOR.xsf
		    ~/Skrypty/awk-matrix/matrix-mult.awk $dir/tmp_frac $dir/tmp_cell >> $dir/tmp_xyz_raw
		    awk '{printf "%.10f %.10f %.10f \n", $1, $2, $3 }' $dir/tmp_xyz_raw > $dir/tmp_xyz
		    ~/Skrypty/awk-matrix/matrix-transpose.awk $dir/tmp_mag_x_row >> $dir/tmp_mag_x
			sed -e 's/[0-9]\+/0/g'  $dir/tmp_mag_x > $dir/tmp_mag_y 
			cp $dir/tmp_mag_y  $dir/tmp_mag_z
		    paste $dir/tmp_at $dir/tmp_xyz $dir/tmp_mag_y $dir/tmp_mag_z $dir/tmp_mag_x  >> $dir/CONTCAR.xsf
			sed -i 's/\t/\t /g' $dir/CONTCAR.xsf 
			sed -i 's/\t -/\t-/g' $dir/CONTCAR.xsf 
			#CONTCAR_VECTOR.xsf
		   fi
	       	
	       rm -f TEMP2 #usuwanie TEMP z magnetyzacją
		   #echo >> $TEMP4_mag  #PART1
         #fi
		 echo >> $outfile1_sub_mag #PART2 albo dodaj linie jeszcze 1 poziom niżej jak w PART3
		 less $TEMP4_mag >> $outfile1
		 rm -f $TEMP4_mag
		 #echo >> $outfile1 #PART2 albo dodaj linie jeszcze 1 poziom niżej jak w PART3
		 #echo 'kolinearne'
	    
		
		#PART FOR NONCOLLINEAR Magnetizations_of_ions
		
        #elif grep -q 'LNONCOLLINEAR =      T' $dir/OUTCAR; then
        elif [[ $ncol_tag = "T" ]] ; then
		 rm -f $dir/TEMP_ncol_*
		 echo 'non-collinear'
	     if grep -q 'General timing and accounting informations for this job' $dir/OUTCAR; then
		   printf %-70s  $dir' ' >> $outfile1_sub_mag  
		   printf %-70s  $dir' ' >> $TEMP4_mag 
		   
		   #CONTCAR_VECTOR.xsf
		   rm -f $dir/tmp_*
           echo 'CRYSTAL' > $dir/CONTCAR.xsf
           echo 'PRIMVEC' >> $dir/CONTCAR.xsf 
           sed -n '3,5p' $dir/CONTCAR >> $dir/tmp_cell
           sed -n '3,5p' $dir/CONTCAR >> $dir/CONTCAR.xsf
           echo 'PRIMCOORD' >> $dir/CONTCAR.xsf 
           at_types=$(sed -n 6p $dir/CONTCAR )
           at_count=$(sed -n 7p $dir/CONTCAR )
           at_no=$(sed -n 7p $dir/CONTCAR | awk '{for(i=1;i<=NF;i++) t+=$i; print t;  t=0}')
           echo $at_no ' 1' >> $dir/CONTCAR.xsf 
		   cp $dir/CONTCAR.xsf $dir/CONTCAR_rough.xsf
		   counter=0
		   for p in $at_count; do
		     counter=$[$counter +1]
			 #echo $p 'p'
			 #echo $counter
			 at=$(echo $at_types | cut -d ' ' -f $counter )
			 #echo $at
		     for ((l=1;l<=$p;l++)); do
			   printf  %-5s "$at" >> $dir/tmp_at
			   echo >> $dir/tmp_at
			 done
		   done
		   
		   #problem z selected dynamics
		   if grep -q -i 'sel' $dir/CONTCAR ; then 
		    sed -n '10,$p' $dir/CONTCAR | head -n $at_no > $dir/tmp_frac_sel
			awk 'NF{NF-=3};3' < $dir/tmp_frac_sel > $dir/tmp_frac
		   else 
		    sed -n '9,$p' $dir/CONTCAR | head -n $at_no > $dir/tmp_frac
		   fi
		   
		   
		   #CONTCAR_VECTOR.xsf
		   
		   
           for k in {x,y,z}; do
	         printf %-70s $dir' ' >> $outfile3_magnetization_ncol
             printf %-2s $k >> $outfile3_magnetization_ncol
		   
             grep -a -B 800 'General timing and accounting informations for this job' $dir/OUTCAR > TEMP
	         printf "$dir\n" >> $outfile2_magnetization
			 
			 if grep -q -a 'tot       ' TEMP; then
              sed -n "/magnetization ($k)/, /tot      /{p; /tot      /q}" TEMP | sed '1,2d' > TEMP2
			  
	          less TEMP2 >> $outfile2_magnetization
			  echo >> $outfile2_magnetization
	          
	          sed -i '1,2d' TEMP2 ; head -n -2 TEMP2 > TEMP; mv TEMP TEMP2
			  #number - liczba atomów
	          #number=$( tail -1 TEMP2 | head -1 | cut -c 4-6) 
			 else 
			  grep -A4 "magnetization ($k)" TEMP | tail -1  > TEMP2
			 fi
			 lastline=$( tail -1 TEMP2 | head -1 )
		     number=$( echo $lastline | cut -f 1 -d ' ' )
	         #echo $number ' lol'
	         
			 for ((i=$number;i">="1;i--)); do
	          lastline2=$( tail -$i TEMP2 | head -1 )
			  atom=$(echo $lastline2 | cut -f 1 -d ' ')
			  if grep -q 'd       f       tot' $dir/OUTCAR; then
		   	    magnetization=$(echo $lastline2 |  cut -f 6 -d ' ' | tr -d '\n' ) 
		   	  else
		   	    magnetization=$(echo $lastline2 |  cut -f 5 -d ' ' | tr -d '\n' ) 
		   	  fi
		   	  LANG=C printf "%7.3f" $magnetization >> $outfile3_magnetization_ncol 
		   	  LANG=C printf "%7.3f" $magnetization >> $dir/TEMP_ncol_$atom
		   	  LANG=C printf "%7.3f" $magnetization >> $dir/tmp_mag_$k
		   	  #if [[ "0.20" > "$magnetization" ]]; then  # <- problem, bo to nie moduł liczby
			  if [[ "0.20" > "${magnetization#-}" ]]; then  # musi być moduł liczby
			    LANG=C printf "%7.3f" 0 >> $dir/tmp_mag_rough_$k
			  else 
			    LANG=C printf "%7.3f" $magnetization >> $dir/tmp_mag_rough_$k
		      fi
			  echo >> $dir/tmp_mag_$k
			  echo >> $dir/tmp_mag_rough_$k
	         done
			 
             #for ((i=1;i"<="$number;i++)); do
	         #    sed -n "$i"p TEMP2 | cut -c 36-43 | tr -d '\n' >> $outfile3_magnetization_ncol
	         #done
	         
			 rm -f TEMP2 #usuwanie TEMP z magnetyzacją
		     echo >> $outfile3_magnetization_ncol 
		     #echo >> $dir/TEMP_ncol_$atom 
           done
		   
		   #CONTCAR_VECTOR.xsf
		   ~/Skrypty/awk-matrix/matrix-mult.awk $dir/tmp_frac $dir/tmp_cell >> $dir/tmp_xyz_raw
		   awk '{printf "%.10f %.10f %.10f \n", $1, $2, $3 }' $dir/tmp_xyz_raw > $dir/tmp_xyz
		   paste $dir/tmp_at $dir/tmp_xyz $dir/tmp_mag_rough_x $dir/tmp_mag_rough_y $dir/tmp_mag_rough_z >> $dir/CONTCAR_rough.xsf
		   paste $dir/tmp_at $dir/tmp_xyz $dir/tmp_mag_x $dir/tmp_mag_y $dir/tmp_mag_z >> $dir/CONTCAR.xsf 
		   mv $dir/CONTCAR_rough.xsf  $dir/CONTCAR_rough-tabs.xsf 
		   mv $dir/CONTCAR.xsf        $dir/CONTCAR-tabs.xsf 
		   tr -d "\t" < $dir/CONTCAR_rough-tabs.xsf >  $dir/CONTCAR_rough.xsf
		   tr -d "\t" < $dir/CONTCAR-tabs.xsf >  $dir/CONTCAR.xsf
		   rm $dir/CONTCAR*tabs*
		   #CONTCAR_VECTOR.xsf
		   
		   #dodanie rotacji względem SAXIS
		   grep -i 'SAXIS' $dir/INCAR > $dir/temp_saxis
		   cd  $dir/
		   python ~/Skrypty/noncol_rot_saxis.py #tworzy plik $dir/temp_xsf
		   cd $curdir
		   sed -n '1,7p' $dir/CONTCAR.xsf > $dir/CONTCAR_saxis.xsf 
		   cat $dir/temp_xsf >> $dir/CONTCAR_saxis.xsf 
		   rm -f $dir/temp_saxis  $dir/temp_xsf
		   #dodanie rotacji względem SAXIS
		      		   
		   for ((atom=1;atom<=$number;atom++)); do
             #echo $atom
			 #Długość wektora
             ##sq_mag=$(awk '{s += ($1)^2+($2)^2+($3)^2}; {t=s^0.5}; END{print (t+0)/NR}' $dir/TEMP_ncol_$atom)
             ###sq_mag=$(awk -F'[-,]' 'function abs(v) {return v < 0 ? -v : v} 
			 ###{s += $1*abs($1)+$2*abs($2)+$3*abs($3)}; {t=s^0.5}; END{print (t+0)/NR}' $dir/TEMP_ncol_$atom)
			 sq_mag=$(awk '{if  ($1+$2+$3 > 0)  {{s += ($1)^2+($2)^2+($3)^2}; {t=s^0.5}}
             else {s += ($1)^2+($2)^2+($3)^2 ; t=-s^0.5 }}; END{print (t+0)/NR}' $dir/TEMP_ncol_$atom)
   
			 LANG=C printf "%7.3f" $sq_mag >> $TEMP4_mag 
			 LANG=C printf "%7.3f" $sq_mag >> $outfile1_sub_mag
           done
		   
		   less $TEMP4_mag >> $outfile1
		   rm -f $TEMP4_mag
		   
		   echo >> $outfile1_sub_mag 
			
		   echo >> $outfile3_magnetization_ncol
	     fi
	    fi
	    #end of COLLINEAR and NONCOLLINEAR
     fi		
	 #end of szukanie magnetization
  
     #W PRZYPADKU GDY ZADANIE JEST PUSZCZONE, ALE CZEKA W KOLEJCE
 elif [ -e $dir/POSCAR ]; then
   printf %-70s  $dir >> $outfile1
   printf %-17s 'Job_queued_or_not_started' >> $outfile1
   #printf %-50s  $dir >> $TEMP4_mag PART3
 fi
 #echo >> $TEMP4_mag  PART3
 #fi
echo >> $outfile1
rm -f $dir/TEMP_ncol_*
rm -f $dir/tmp_*
fi


fi 
#koniec pętli z folderami
done < list
rm -f list

echo >> $outfile1
less  $outfile1_sub_mag >> $outfile1
#less  $TEMP4_mag >> $outfile1

 if [ -e TEMP3 ]; then
	echo >> $outfile1
	printf "supercells...\n" >> $outfile1
	less TEMP3 >> $outfile1
 fi

rm -f $TEMP4_mag
rm -f $outfile1_sub_mag
rm -f TEMP*
