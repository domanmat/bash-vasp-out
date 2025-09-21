#dodaje macierze z plików inputowych
# for i in {25..46}; do printf $i"," ; done
 gawk '
    {
        for (i=1; i<=NF; i++)
            m[i][FNR] += $i
    }
    END {
        for (y=1; y<=FNR; y++) {
            for (x=1; x<=NF; x++)
                printf "%f ", m[x][y]
            print ""
        }
    }
' $@ > DOSCAR_0sum
echo SUCCESS $@ matrices added 

#użycie:
# ~/Skrypty/awk-matrix/matrix-add3.sh DOSCAR_at{1,2} 
# ~/Skrypty/awk-matrix/matrix-add3.sh DOSCAR_at{3,4,5,6} 
# ~/Skrypty/awk-matrix/matrix-add3.sh DOSCAR_at{7,8} 
# ~/Skrypty/awk-matrix/matrix-add3.sh DOSCAR_at{9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24} 
# ~/Skrypty/awk-matrix/matrix-add3.sh DOSCAR_at{25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46} 

