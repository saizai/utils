find -E -d . -regex "(^|.*/)(Icon|\.DS_Store|desktop\.ini)[[:space:][:blank:][:cntrl:][:punct:]_?]*[^[:print:]]*$" -print -delete
