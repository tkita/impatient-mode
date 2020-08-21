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

// var frameToDocument = function( iframe ) {
//     return ( iframe.contentDocument ) ? iframe.contentDocument : iframe.Document;
// };

// var printIframe = function( data ) {
//     document.getElementById( 'marked' ).innerHTML = marked( data );
// };

// var setIframe = function( count, newText ) {
var md2html = function( count, mdText ) {
    if ( !count ) {
        // error parsing client result
        // printIframe( '0', 'error parsing the response from emacs' );
        document.getElementById( 'marked' ).innerHTML = 'error parsing the response from emacs';
    } else {
        current_id = count;
        // printIframe( newText );
        document.getElementById( 'marked' ).innerHTML = marked( mdText );
        console.log( mdText );
    }
};

var refresh = function() {
    /* var url = "/imp/buffer/" + buffer;
       
     * var gotData = function(data, status, xhr) {
     *     resetTimeout();
     *     setIframe(xhr.getResponseHeader("X-Imp-Count"), data);
     *     refresh();
     * };

     * var errorRetry = function() {
     *     setTimeout(refresh, nextTimeout());
     * };

     * $.get(url + '?id=' + current_id, gotData).error(errorRetry);
     */
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

/* $(document).ready(function() {
 *   var iframeJQ = $('#content');
 *   iframeJQ.load(function() {
 *     // now we need to tweak the stylesheet links so that firefox will
 *     // refresh them properly
 *     $('link', frameToDocument(iframeJQ[0])).each(function(index, el) {
 *       var href = $(el).attr('href');
 *       // Only refresh impatient-mode hosted content
 *       if(href && !/^[a-zA-z]+:\/\//.exec(href)) {
 *         $(el).attr('href', $(el).attr('href') + '?' + new Date().getTime());
 *       }
 *     });
 *   });
 * 
 *   refresh();
 * }); */
document.addEventListener( 'DOMContentLoaded', function() {
    refresh();
});