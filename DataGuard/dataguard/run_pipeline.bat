@echo off
cd C:\Users\USER\Desktop\dataguard
call dataguard-env\Scripts\activate
cd cafe_rewards
dbt run
cd ..
python validate.py