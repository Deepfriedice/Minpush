Test the numbers up to one thousand for primality.


Load 2 into X and then start.
{start: d2D X d0D Y :split_x}

Prepare to print X.
{ split_x :
  d0D Z                   (set z to 0)
  x W $                   (copy x to w)
  w d0D = ?print_digits;  (stop if w=0)
  w d10D %                (get lowest digit from w)
  w d10D / W              (divide w by 10)
  oA                      (write lowest digit to array)
  z d1D + Z               (increment z)
}

Print the digits stored in the array.
{ print_digits :
  z d0D = ?test_prime;    (stop when there are no more digits)
  L d1D - op              (peek the last byte of the array)
  L d1D - S               (shorten the array by one)
  `0 + .                  (print the character)
  z d1D - Z               (decrement z)
}

Test if we've checked all prime divisors.
{ test_prime :
  L d4D /                 (count number of known primes)
  y = ?is_prime;          (if y = #primes, then x is prime)
: test_div }

Test if x is divisible by the yth prime.
{ test_div :
  x
  d4D y * Ep              (get yth prime from array)
  % d0D =                 (check if divisible)
  ?is_div;
: is_not_div }

X was divisible by the yth prime.
{is_div: :is_not_prime}

X was not divisible by the yth prime.
{ is_not_div :
  y d1D + Y               (increment y)
: test_prime }

Print a success message and add the prime to the array.
{ is_prime :
  ' is prime"
  L d9D - d9D _
  L d9D - S
  x EA
  haH.
:loop }

Print a failure message.
{ is_not_prime :
  ' is not prime"
  L d13D - d13D _
  L d13D - S
  haH.
:loop }

Increment y, clear y and then start again.
{ loop :
  x d1000D = ?stop;
  x d1D + X
  d0D Y
: split_x }
