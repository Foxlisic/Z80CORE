10 INK 7: PAPER 0: BORDER 0: CLS
20 DIM a(5,2)
30 FOR i=1 TO 5
40 LET a(i,1)=128-50+100*(i=2 OR i=3)
50 LET a(i,2)=88-50+100*(i=3 OR i=4)
60 NEXT i
70 FOR i=1 TO 4
80 PLOT a(i,1),a(i,2)
90 DRAW a(i+1,1)-a(i,1),a(i+1,2)-a(i,2)
100 LET a(i,1)=0.95*a(i,1)+0.05*a(i+1,1)
110 LET a(i,2)=0.95*a(i,2)+0.05*a(i+1,2)
120 NEXT i
130 LET a(5,1)=a(1,1)
140 LET a(5,2)=a(1,2)
150 GO TO 70
