const bcrypt = require("bcrypt");
const password = "123456a";
bcrypt.hash(password, 10, function (err, hash) {
  if (err) throw err;
  console.log(hash);
});
