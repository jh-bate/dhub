# This file should be run with 'source' (also known as '.' on linux/macs).
#
# It creates several functions that allow the user to login and then query data
# via the octopus query endpoint.
#
# Note that this is currently set up to query the Tidepool development server.
# However, you can change the TIDEPOOL_SERVER environment variable and
# use a different server. See Tidepool for details

# Use the first line if you're running a local server.
# Most people will use the second for Tidepool's dev server.
#
#
# Usage example:
#-------------------
#
# $ . tidepool_platform
#
# $ tp_login c@c.com
# Enter host password for user 'c@c.com':
# {"userid":"467c4642d5","username":"c@c.com","emails":["c@c.com"]}
# You're now logged in.
#
# At this point, the email is set as the default userid. You can change it:
#
# $ tp_setuser 467c4642d5
# User ID now set to '467c4642d5'.
#
# $ tp_settypes cbg
# Query types now set to 'cbg'.
#
# $ tp_setstartdate 2014-08-20
# Query start date now set to '2014-08-20T00:00:00.000Z'.
#
# $ tp_setenddate 2014-08-21
# Query end date now set to '2014-08-21T00:00:00.000Z'.
#
# $ tp_query >output.txt
# The query will be:
# METAQUERY WHERE userid IS 467c4642d5 QUERY TYPE IN cbg WHERE time > 2014-08-20T00:00:00.000Z AND time < 2014-08-21T00:00:00.000Z SORT BY time AS Timestamp REVERSED

# Enter to run the query or [c] to cancel:
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100  100k    0  100k  100   163  20347     32  0:00:05  0:00:05 --:--:-- 22766
#   [10:32 AM][~/tidepool/octopus][kjq/cleanerQuery]
#-------------------


# you can also do it all in one command (with more variation possible) like this:
# tp_query 467c4642d5 cbg "WHERE time > 2014-08-20T00:00:00.000Z AND time < 2014-08-21T00:00:00.000Z"


tp_setserver() {
    if [ "$1" = "local" ]; then
        TIDEPOOL_SERVER="http://localhost:8009"
    elif [ "$1" = "devel" ]; then
        TIDEPOOL_SERVER="https://devel-api.tidepool.io"
    elif [ "$1" = "staging" ]; then
        TIDEPOOL_SERVER="https://staging-api.tidepool.io"
    elif [ "$1" = "prod" ]; then
        TIDEPOOL_SERVER="https://api.tidepool.io"
    else
        echo "you must specify local, devel, staging, or prod"
    fi
}

tp_setserver devel

# Login to the tidepool-platfrom and get a session-token
tp_login() {

    if [ -z "$1" ]; then
        echo "your user name is required (i.e. tp_login <username>)"
        return
    fi

    # save the headers in a tempfile so we can extract the token
    TEMPFILE="tplogin-$$.tmp"
    curl -s -X POST --dump-header $TEMPFILE -u $1 $TIDEPOOL_SERVER/auth/login
    # now put the token in the environment
    export LOGIN_TOKEN=$(grep "x-tidepool-session-token:" $TEMPFILE |tr -d '\n\r')
    rm $TEMPFILE

    # are you logged in?
    if [ -z "$LOGIN_TOKEN" ]; then
        echo ""
        echo "Something went wrong trying to login. Bad password? Wrong server?"
        return
    fi
    # let's save the user id for you
    export TP_USERID=$1
    echo ""
    echo "You're now logged in."
}

# Logout by clearing the token we are storing
tp_logout() {
    export LOGIN_TOKEN=
    echo ""
    echo "You have now logged out."
}

tp_save() {

    url -X POST -H "$LOGIN_TOKEN" -d "$QUERY" $TIDEPOOL_SERVER/query/data
}

_validation() {

    # are you logged in?
    if [ -z "$LOGIN_TOKEN" ]; then
        echo "please login first i.e. tp_login <username>"
        return
    fi

    # do we have a user id for us to query?
    if [ -z "$TP_USERID" ]; then
        if [ -z "$1" ]; then
            echo "we need the id of the user whose data you are querying i.e. tp_query <userid>"
            return
        else
            TP_USERID=$1
        fi
    fi

}

# Run the data query for a given user id
tp_query() {

    _validation

    # do you want to constrain the query by time?
    QUERY_WHERE=""

    if [ -n "$3" ]; then
        # e.g. "WHERE time > 2014-11-24T05:00:00.000Z AND time < 2014-12-24T05:00:00.000Z"
        QUERY_WHERE=$3
    else
        if [ -n "$TP_STARTDATE" -a -n "$TP_ENDDATE" ]; then
            QUERY_WHERE="WHERE time > $TP_STARTDATE AND time < $TP_ENDDATE"
        elif [ -n "$TP_STARTDATE" ]; then
            QUERY_WHERE="WHERE time > $TP_STARTDATE"
        elif [ ]; then
            QUERY_WHERE="WHERE time < $TP_ENDDATE"
        fi
    fi

    QUERY="METAQUERY WHERE userid IS $TP_USERID QUERY TYPE IN $QUERY_TYPES $QUERY_WHERE SORT BY time AS Timestamp REVERSED"

    # send these prompts to stdout so that you can redirect the output of this
    # command to a file to save the result
    >&2 echo "The query will be:"
    >&2 echo $QUERY
    >&2 echo ""
    read  -p "Enter to run the query or [c] to cancel:" input

    if [ "$input" = "c" ]; then
        echo ""
        echo "Query cancelled."
    else
        curl -X POST -H "$LOGIN_TOKEN" -d "$QUERY" $TIDEPOOL_SERVER/query/data
    fi
}

tp() {
    if [ "$1" = "help" -o "$1" = "" -o "$1" = "-?" ]; then
        echo "Helps you do certain structured queries to Tidepool servers."
        echo "Supported commands: "
        echo "   tp login email@addr.com"
        echo "   tp setserver SERVER -- SERVER can be local, devel, staging, or prod"
        echo "   tp query -- runs a normal query"

    elif [ "$1" = "login" ]; then
        shift
        tp_login $*
    elif [ "$1" = "logout" ]; then
        shift
        tp_logout $*
    elif [ "$1" = "query" ]; then
        shift
        QUERY=$*
        curl -s -X POST -H "$LOGIN_TOKEN" -d "$QUERY" $TIDEPOOL_SERVER/query/data
    else
        echo "command '$1' not understood. Type 'tp help' for help."
    fi
}

echo "Type 'tp help' for help."

