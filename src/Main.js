exports.logRaw = function(e) {
  return function() {
    console.log(e)
  }
}
