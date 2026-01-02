# ARC4-Decryption-Unit

ARC4 is a symmetric stream cipher, once widely used in encrypting web traffic and wireless data, but has since been broken.

In this project, an encrypted message in the form of a memory initialization file (.mif) is inputted by the user into the ciphertext memory (ct_mem.v). Next, the unit will run multiple decryption units in parallel by cycling through the entire key space and generating pseudo-random byte streams for each respective key that is xor'd with the ciphertext. Once a successful decryption is performed (the plaintext is filled with all ASCII characters), the recovered message is found in the plaintext memory (pt_mem.v). 

To speed the decryption time up, multiple cracking units (104 to be exact) work in parallel to cycle through the entire keyspace at around 7 million keys per second. In multicrack.sv, generate statements and for loops were used to streamline module instantiations. Furthermore, a PLL was used to increase the clock speed of the FPGA from 50MHz to 115MHz. This resulted in a cracking time of a message with key 24'hF001ED to be achieved in 2.77 seconds rather than 6 minutes 50 seconds for one cracking module only. 
