# the-shipyard

Be sure to setup a virtual environment (venv)!! 
```bash
python -m venv .env 
```
(name it .env so .gitignore catches it, saves a lot of headaches)

For this .env, you then need to run: 
```bash 
pip install requirements.txt
```

This should download all dependencies :) and perhaps a few more than whats needed... 
This dependency is vital for us.

## Computer Vision 

### Symbols 

denotes which side of the piece is laying down. 

- Hull Bow 
  - 0 UP FORWARD
  - 1 UP BACKWARD
  - 2 DOWN FORWARD
  - 3 DOWN BACKWARD

- Hull Stern 
  - 4 UP FORWARD
  - 5 UP BACKWARD
  - 6 DOWN FORWARD
  - 7 DOWN BACKWARD

- Hull Section 
  - 8 UP 
  - 9 DOWN

- Cabin
  - 10 default 
- Chimney
  - 11 default 
- Sail 
  - 12 FORWARD
  - 13 BACKWARD
- 


## Parsing & Boat
