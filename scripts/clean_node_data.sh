# Delete all data files older than 3 hours
find "/home/ubuntu/hl/data" -type f -mmin +180 -delete