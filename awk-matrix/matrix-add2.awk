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
' DOSCAR_at{25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46} > DOSCAR_25-46sum

