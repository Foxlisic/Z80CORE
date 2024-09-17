10 LET h=75
20 LET cx=0: LET cy=-1.2: LET cz=3.5
30 LET al=0.5
40 DATA -1,1,1, 1,1,1, 1,-1,1, -1,-1,1, -1,1,-1, 1,1,-1, 1,-1,-1, -1,-1,-1
50 DATA 2,1,4,3, 5,6,7,8, 1,2,6,5, 3,4,8,7, 6,2,3,7, 1,5,8,4
60 DIM v(8,3): DIM f(6,4): DIM w(8,2)
70 FOR i=1 TO 8: READ v(i,1),v(i,2),v(i,3): NEXT i
80 FOR i=1 TO 6: READ f(i,1),f(i,2),f(i,3),f(i,4): NEXT i
90 LET ca=COS(al): LET sa=SIN(al)
100 FOR i=1 TO 8
110 LET x=cx + v(i,1)*ca - v(i,3)*sa
120 LET y=cy + v(i,2)
130 LET z=cz + v(i,3)*ca + v(i,1)*sa
140 LET w(i,1)=128 + h*x/z
150 LET w(i,2)=88 + h*y/z
160 NEXT i
165 CLS
170 FOR i=1 TO 6
180 LET f1=f(i,1): LET f2=f(i,2): LET f3=f(i,3): LET f4=f(i,4)
190 LET ABx=w(f2,1)-w(f1,1)
200 LET ABy=w(f2,2)-w(f1,2)
210 IF (w(f3,1)-w(f1,1))*ABy < (w(f3,2)-w(f1,2))*ABx THEN GO TO 270
220 PLOT w(f1,1), w(f1,2)
230 DRAW ABx,ABy
240 DRAW w(f3,1)-w(f2,1),w(f3,2)-w(f2,2)
250 DRAW w(f4,1)-w(f3,1),w(f4,2)-w(f3,2)
260 DRAW w(f1,1)-w(f4,1),w(f1,2)-w(f4,2)
270 NEXT i
280 LET al = al + 0.1
290 GO TO 90
