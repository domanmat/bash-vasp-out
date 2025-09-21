awk '
ARGIND == 1 {
  for(i=1; i<=NF; i++)
    m1[FNR][i] = $i
  m1_width  = NF
  m1_height = FNR
}

#ARGIND == 2 {
#  for(i=1; i<=NF; i++)
#    m2[FNR][i] = $i
#  m2_width  = NF
#  m2_height = FNR
#}

END {
#  if(m1_width != m2_height) {
#    print "Matrices are incompatible, unable to multiply!"
#    exit 1
#  }
  for(i=1; i<=m1_height; i++) {
    #for(j=1; j<=m2_width; j++) 
      for(k=1; k<=m1_width; k++) {
        sum += m1[i][k] * m1[i][k]
        printf sum OFS; sum=0
      }
    printf ORS
  }
}' $1