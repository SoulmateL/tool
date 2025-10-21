/**
 * Minified by jsDelivr using Terser v5.39.0.
 * Original file: /npm/markdown-it-sub@1.0.0/index.js
 *
 * Do NOT use SRI with dynamically generated files! More information: https://www.jsdelivr.com/using-sri-with-dynamic-files
 */
"use strict";var UNESCAPE_RE=/\\([ \\!"#$%&'()*+,.\/:;<=>?@[\]^_`{|}~-])/g;function subscript(s,p){var r,o,e=s.posMax,u=s.pos;if(126!==s.src.charCodeAt(u))return!1;if(p)return!1;if(u+2>=e)return!1;for(s.pos=u+1;s.pos<e;){if(126===s.src.charCodeAt(s.pos)){r=!0;break}s.md.inline.skipToken(s)}return r&&u+1!==s.pos?(o=s.src.slice(u+1,s.pos)).match(/(^|[^\\])(\\\\)*\s/)?(s.pos=u,!1):(s.posMax=s.pos,s.pos=u+1,s.push("sub_open","sub",1).markup="~",s.push("text","",0).content=o.replace(UNESCAPE_RE,"$1"),s.push("sub_close","sub",-1).markup="~",s.pos=s.posMax+1,s.posMax=e,!0):(s.pos=u,!1)}module.exports=function(s){s.inline.ruler.after("emphasis","sub",subscript)};
//# sourceMappingURL=/sm/7deaba9d4110652b22f489bab340ff02d64c82830972a13b3752436b6cbbd4b4.map