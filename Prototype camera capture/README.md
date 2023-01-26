## Camera control (script only)

### General information
#### Pros
- Can acquire the accurate timestamps when each frame was taken
- Videos are recorded on separate cores to minimize the delay.
- Can be an external trigger by sending a square pulse to a NIDAQ channel
  
#### Cons
- Have to specify the duration of the recording session beforehand.
- The drift is still there.
- NO GUI