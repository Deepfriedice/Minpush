Print the decimal representation of a number.


{ start :
  d47043D X
: split_x }

{ split_x :
  x W $              (copy x to w)
  w d0D = ?print_x;  (stop if w=0)
  w d10D %           (get lowest digit from w)
  w d10D / W         (divide w by 10)
  oA                 (write lowest digit to array)
}

{ print_x :
  L d0D = ?stop;     (stop when there are no more digits)
  L d1D - op         (peek the last byte of the array)
  L d1D - S          (shorten the array by one)
  `0 + .             (print the character)
}
