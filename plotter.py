from sys import stdin
import matplotlib.pyplot as plt

plt.imshow([[0,0],[0,0]])
plt.show(block=False)
plt.pause(0.01)
for line in stdin:
  array = eval(line)
  plt.imshow(array)
  plt.draw()
  plt.pause(0.01)
#plt.pause(10)
plt.imshow(array)
plt.show(block=True)
