#!/usr/bin/python
import sys
import math

f=open('CONTCAR.xsf','r')
f2=open('temp_saxis','r')

a=f.readlines()
nel = int(a[6].split()[0])
#print(nel)

a2=f2.readlines()
x_saxis = float(a2[0].split()[2])
y_saxis = float(a2[0].split()[3])
z_saxis = float(a2[0].split()[4])
alpha = math.atan2(y_saxis, x_saxis)
beta = math.atan2(x_saxis**2+y_saxis**2, z_saxis)
#print x_saxis, y_saxis, z_saxis
#print alpha, beta

#alpha=ATAN(x/(y))
#beta=ATAN((x^2+y^2)/c)

out=open("temp_xsf","w+")

for j in range(nel): 
    #print(j)
    el = (a[7+j].split()[0])
    x = float(a[7+j].split()[1])
    y = float(a[7+j].split()[2])
    z = float(a[7+j].split()[3])
    mx_axis = float(a[7+j].split()[4])
    my_axis = float(a[7+j].split()[5])
    mz_axis = float(a[7+j].split()[6])
    mx = (math.cos(beta)*math.cos(alpha)*mx_axis - math.sin(alpha)*my_axis + math.sin(beta)*math.cos(alpha)*mz_axis )
    my = (math.cos(beta)*math.sin(alpha)*mx_axis + math.cos(alpha)*my_axis + math.sin(beta)*math.sin(alpha)*mz_axis )
    mz = ( - math.sin(beta)*mx_axis + math.cos(beta)*mz_axis )
    #mx = float(a[7+j].split()[4])
    #my = float(a[7+j].split()[5])
    #mz = float(a[7+j].split()[6])
    #mx_axis = (math.cos(beta)*math.cos(alpha)*mx + math.cos(beta)*math.sin(alpha)*my - math.sin(beta)*mz )
    #my_axis = ( - math.sin(alpha)*mz + math.cos(alpha)*my )
    #mz_axis = (math.sin(beta)*math.cos(alpha)*mx + math.sin(beta)*math.sin(alpha)*my + math.cos(beta)*mz )
    print >> out, el.ljust(4), " ", format(x, '.10f').rjust(15), " ", format(y, '.10f').rjust(15), " ", format(z, '.10f').rjust(15), " ", format(mx, '.3f').rjust(6), " ", format(my, '.3f').rjust(6), " ", format(mz, '.3f').rjust(6), " "


##string1 = "PYTHON"
##print("String: ",string1)
##
### Pad right using rjust()
##print string1.ljust(10), nel
