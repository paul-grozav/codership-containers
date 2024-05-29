/*
  this file must create 100 rows.
  do not change the data!
*/

DROP DATABASE IF EXISTS `testdb`;

CREATE DATABASE `testdb`;

USE `testdb`

DROP TABLE IF EXISTS `myTable`;

CREATE TABLE `myTable` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `email` varchar(255) default NULL,
  `country` varchar(100) default NULL,
  PRIMARY KEY (`id`)
) AUTO_INCREMENT=1;

INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Igor Glover","diam.pellentesque@google.ca","Sweden"),
  ("Isabella Tanner","placerat.velit@hotmail.org","Mexico"),
  ("Nathaniel Merritt","vitae.nibh@hotmail.couk","South Korea"),
  ("Carlos Wolfe","senectus.et.netus@hotmail.net","Spain"),
  ("Steven Harmon","neque@yahoo.org","Ukraine"),
  ("Jenna Holder","mi.aliquam@google.org","Netherlands"),
  ("Clinton Mullen","vestibulum.lorem@aol.ca","India"),
  ("Rajah Waters","scelerisque.scelerisque@outlook.net","Spain"),
  ("Ainsley Washington","vel.pede.blandit@google.ca","Vietnam"),
  ("Jenette Cooley","metus.eu.erat@outlook.com","Canada");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Blake Roth","integer.mollis@outlook.ca","France"),
  ("Wyoming Serrano","sagittis.placerat.cras@yahoo.ca","Pakistan"),
  ("Francis Flynn","tincidunt.donec@icloud.edu","Indonesia"),
  ("Ronan Sloan","ante@yahoo.net","India"),
  ("Rashad Rocha","nec@icloud.net","Ukraine"),
  ("Baxter Finley","neque.et@protonmail.ca","Vietnam"),
  ("Tyrone Barker","rutrum.magna@icloud.com","Poland"),
  ("Mia Mercer","mauris.nulla@hotmail.ca","United States"),
  ("Dara Schwartz","mi.duis@aol.net","Ireland"),
  ("Igor Flynn","semper.cursus@google.net","Norway");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Quamar Carter","pede@google.couk","Sweden"),
  ("Victor Crane","eget.mollis.lectus@google.ca","Turkey"),
  ("Aquila Jenkins","elit.erat.vitae@google.ca","New Zealand"),
  ("Carl Crosby","a.malesuada.id@yahoo.edu","France"),
  ("Ulysses Whitaker","risus.quis.diam@yahoo.ca","Singapore"),
  ("Lysandra Garrett","nulla.eget@google.org","New Zealand"),
  ("Phoebe Bennett","et.ultrices.posuere@outlook.com","Costa Rica"),
  ("Lydia Dorsey","a.enim@hotmail.edu","Canada"),
  ("George Gibson","tincidunt.dui@google.edu","Norway"),
  ("Kermit Sweeney","a@icloud.net","United States");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Bevis Hood","lacinia.vitae@protonmail.ca","South Africa"),
  ("Chastity Case","quis.pede.praesent@protonmail.net","Netherlands"),
  ("Bradley Gordon","hendrerit.a@yahoo.couk","Pakistan"),
  ("Lamar Livingston","arcu.et@protonmail.edu","United States"),
  ("Keegan Hogan","fringilla.porttitor.vulputate@protonmail.edu","Singapore"),
  ("Dexter Lee","et.euismod@aol.edu","China"),
  ("Boris Finch","ligula.donec.luctus@hotmail.net","United Kingdom"),
  ("Kathleen Barton","sapien.molestie.orci@icloud.org","Turkey"),
  ("Naida Gordon","pellentesque.massa@hotmail.com","Australia"),
  ("Quemby Reyes","blandit@google.com","Netherlands");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Gray Washington","quis.pede@icloud.edu","Nigeria"),
  ("Priscilla Koch","eu.enim@protonmail.edu","New Zealand"),
  ("Abel Bradley","pharetra.ut@hotmail.org","United Kingdom"),
  ("Kylee Drake","sem.consequat@outlook.org","Austria"),
  ("Meredith Parsons","felis.nulla@outlook.com","South Korea"),
  ("Tanisha Hardy","dis.parturient@hotmail.edu","Colombia"),
  ("Clinton Ortiz","phasellus@protonmail.net","Italy"),
  ("Ciara Sargent","pellentesque.habitant.morbi@google.com","United States"),
  ("Steel Conley","massa.integer@outlook.couk","Ukraine"),
  ("Gloria Moses","risus@aol.ca","New Zealand");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("TaShya Craig","nunc.ut@icloud.couk","Brazil"),
  ("Daria Giles","nonummy.ultricies@hotmail.net","Ukraine"),
  ("Kylee Pace","aliquam.nisl@outlook.ca","New Zealand"),
  ("Leslie Mccray","eu.dui@outlook.org","Peru"),
  ("Urielle Preston","vitae.purus.gravida@google.com","Brazil"),
  ("Colton Stevens","luctus.curabitur@google.org","China"),
  ("Amaya Hooper","mollis.duis@icloud.edu","France"),
  ("Zane Acosta","integer.in.magna@protonmail.couk","Austria"),
  ("Hammett Moss","velit.pellentesque.ultricies@protonmail.ca","Colombia"),
  ("Cody Holman","nec.quam@icloud.com","United States");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Eliana Russo","arcu.vestibulum@icloud.ca","South Africa"),
  ("Hayden Monroe","auctor.nunc@outlook.edu","United States"),
  ("Warren Ayala","aliquam.tincidunt.nunc@hotmail.net","South Korea"),
  ("Arthur Carr","ut@hotmail.ca","New Zealand"),
  ("Adele Erickson","erat.in.consectetuer@hotmail.com","South Africa"),
  ("Joelle Moreno","sapien.nunc.pulvinar@google.com","Philippines"),
  ("Jade Burgess","proin.dolor.nulla@icloud.com","Nigeria"),
  ("Adrian Haney","primis.in.faucibus@aol.couk","Turkey"),
  ("Vera Logan","quisque.varius@google.edu","Netherlands"),
  ("Sopoline Walters","felis.purus@aol.net","Mexico");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Lacota Carlson","pede.suspendisse@protonmail.org","Ireland"),
  ("Quinlan Pearson","feugiat@aol.couk","China"),
  ("Calvin Walter","vel.est.tempor@outlook.org","South Africa"),
  ("Hope Gillespie","diam.eu.dolor@hotmail.edu","Ukraine"),
  ("Cooper Macias","posuere.cubilia.curae@icloud.com","Sweden"),
  ("Brent Shields","est.vitae@hotmail.couk","Spain"),
  ("Ulric Middleton","maecenas.ornare@protonmail.couk","Austria"),
  ("Patience Melton","ullamcorper@yahoo.ca","Indonesia"),
  ("Aquila Lynn","ac@aol.ca","Canada"),
  ("Jayme Vinson","vestibulum.nec.euismod@protonmail.com","Vietnam");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Demetrius Tate","et.tristique.pellentesque@protonmail.ca","Costa Rica"),
  ("Molly Gomez","blandit@aol.edu","Germany"),
  ("Lionel Cook","tellus.imperdiet@aol.couk","Vietnam"),
  ("Dara Cantrell","nunc.nulla@icloud.net","Vietnam"),
  ("Phillip Perkins","ornare.fusce.mollis@yahoo.ca","New Zealand"),
  ("Quinn Ford","magna.malesuada@aol.net","France"),
  ("Geoffrey Rivera","adipiscing.fringilla@icloud.net","Netherlands"),
  ("Karleigh Mcintosh","dignissim.lacus@outlook.org","Nigeria"),
  ("Hanae Small","consequat.purus.maecenas@google.org","Ireland"),
  ("Cathleen Barron","ante.bibendum@hotmail.net","Peru");
INSERT INTO `myTable` (`name`,`email`,`country`)
VALUES
  ("Charde Roy","leo@outlook.edu","South Korea"),
  ("Patricia Chase","maecenas.libero@yahoo.net","Pakistan"),
  ("Quin White","orci.phasellus.dapibus@hotmail.couk","Spain"),
  ("Paki Valenzuela","maecenas.ornare.egestas@protonmail.com","United Kingdom"),
  ("Cynthia Estrada","ultricies.ornare.elit@hotmail.org","Belgium"),
  ("Ivana Munoz","turpis.in.condimentum@aol.ca","Italy"),
  ("Vivien Buck","mollis.phasellus@icloud.com","Brazil"),
  ("Maya Duffy","odio@google.com","Peru"),
  ("Norman George","adipiscing@yahoo.edu","Netherlands"),
  ("Echo Craft","elementum.sem@aol.edu","Colombia");
