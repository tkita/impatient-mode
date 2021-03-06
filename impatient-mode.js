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

// for highlight.js
marked.setOptions( { langPrefix: '',
                   });

var renderer = new marked.Renderer();
renderer.code = function( code, lang ) {
    if ( 'mermaid' == lang ) {
        return '<pre class="mermaid">' + code + '</pre>';
    } else {
        return '<pre><code>' + code + '</code></pre>';
    };
};

var md2html = function( resCount, resMarkdownText ) {
    if ( !resCount ) {
        // error parsing client result
        document.getElementById( 'marked' ).innerHTML = 'error parsing the response from emacs';
        xhr.onreadystatechange = function() {};
        xhr.abort();
    } else {
        current_id = resCount;
        document.getElementById( 'marked' ).innerHTML = marked( resMarkdownText,
                                                                { renderer: renderer }
                                                              );
        hljs.initHighlighting();
        mermaid.init();
    }
};

var impCtrl = {
    'Goto': function( props ) {
        if ( 'Top' == props ) {
            window.scrollTo( 0, 0 );
        } else {
            var e = document.documentElement;
            window.scroll( 0, e.scrollHeight - e.clientHeight );
        };
    },

    'Recenter': function( props ) {
        window.scroll( 0, document.documentElement.scrollHeight *
                       parseFloat( props ));
    },

    'Scroll': function( props ) {
        if ( typeof window.scrollByLines == 'function' ) {
            window.scrollByLines( props );
        };
    },
};

var xhr = new XMLHttpRequest();
xhr.onreadystatechange = function() {
    if ( 4 == xhr.readyState ) {
        resetTimeout();

        var ctrl = xhr.getResponseHeader( 'X-Imp-Ctrl' );
        if ( 'nil' != ctrl ) {
            impCtrl[ ctrl.split( '/' )[0] ]( ctrl.split( '/' )[1] );
        };

        md2html( xhr.getResponseHeader( 'X-Imp-Count' ),
                 xhr.responseText );
        httpRequest();
    } else {
        // console.log( 'impatient-mode.js: readyState: ' + xhr.readyState );
        // console.log( 'impatient-mode.js: status: ' + xhr.status );
    };
};

xhr.onerror = function() {
    if ( 4 == xhr.readyState && 0 == xhr.status ) {
        console.log( 'impatient-mode.js: onerror'  );
        console.log( 'impatient-mode.js: onerror.readyState: ' + xhr.readyState );
        console.log( 'impatient-mode.js: onerror.status: ' + xhr.status );
        xhr.abort();
    } else {
        setTimeout( httpRequest, nextTimeout() );
    };
};

var httpRequest = function() {
    xhr.open( 'GET', '/imp/buffer/' + buffer + '?id=' + current_id );
    xhr.send();
};

document.addEventListener( 'DOMContentLoaded', function() {
    httpRequest();
});
