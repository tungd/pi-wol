exports.logRaw = function(e) {
  return function() {
    console.log(e)
  }
}

exports.select = function(s) {
  return function() {
    return document.querySelector(s) || null
  }
}
