/**
 * Minified by jsDelivr using Terser v5.39.0.
 * Original file: /npm/markdown-it-sup@1.0.0/index.js
 *
 * Do NOT use SRI with dynamically generated files! More information: https://www.jsdelivr.com/using-sri-with-dynamic-files
 */
"use strict";var UNESCAPE_RE=/\\([ \\!"#$%&'()*+,.\/:;<=>?@[\]^_`{|}~-])/g;function superscript(s,p){var r,o,e=s.posMax,u=s.pos;if(94!==s.src.charCodeAt(u))return!1;if(p)return!1;if(u+2>=e)return!1;for(s.pos=u+1;s.pos<e;){if(94===s.src.charCodeAt(s.pos)){r=!0;break}s.md.inline.skipToken(s)}return r&&u+1!==s.pos?(o=s.src.slice(u+1,s.pos)).match(/(^|[^\\])(\\\\)*\s/)?(s.pos=u,!1):(s.posMax=s.pos,s.pos=u+1,s.push("sup_open","sup",1).markup="^",s.push("text","",0).content=o.replace(UNESCAPE_RE,"$1"),s.push("sup_close","sup",-1).markup="^",s.pos=s.posMax+1,s.posMax=e,!0):(s.pos=u,!1)}module.exports=function(s){s.inline.ruler.after("emphasis","sup",superscript)};
//# sourceMappingURL=/sm/2345c1b7be356e7055f1dd9e110b337c585ea45e5c0d719654ac7482b7b4b58d.map