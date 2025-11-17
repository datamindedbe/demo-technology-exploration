## export the variables from .env
export $(grep -v '^#' .env | xargs)
