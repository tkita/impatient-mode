var buffer = window.location.pathname.split( '/' )[ 3 ];
var max_period = 60000;
var min_period = 1000;
var next_period = min_period;
var alpha = 1.2;
var current_id = '-1';
document.getElementById( 'title' ).textContent = decodeURI( buffer );

var nextTimeout = function() {
    var next = next_period;
    next_period = Math.min( max_period, next_period * alpha );
    return next;
};

var resetTimeout = function() {
    next_period = min_period;
};

var md2html = function( count, mdText ) {
    if ( !count ) {
        // error parsing client result
        document.getElementById( 'marked' ).innerHTML = 'error parsing the response from emacs';
    } else {
        current_id = count;
        document.getElementById( 'marked' ).innerHTML = marked( mdText );
        console.log( mdText );
    }
};

var refresh = function() {
    var xhr = new XMLHttpRequest();
    xhr.open( 'GET', '/imp/buffer/' + buffer + '?id=' + current_id );
    xhr.onreadystatechange = function() {
        if ( 4 == xhr.readyState ) {
            resetTimeout();
            md2html( xhr.getResponseHeader( 'X-Imp-Count' ),
                     xhr.responseText );
            refresh();
        };
    };
    xhr.onerror = function () {
        setTimeout( refresh, nextTimeout() );
    };
    xhr.send();
};

document.addEventListener( 'DOMContentLoaded', function() {
    refresh();
});
