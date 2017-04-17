DROP DATABASE IF EXISTS `demo`;
CREATE DATABASE IF NOT EXISTS `demo`;

DROP TABLE IF EXISTS `demo`.`user`;
DROP TABLE IF EXISTS `demo`.`address`;

CREATE TABLE `demo`.`address` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY
 ,`address` VARCHAR(255) NOT NULL
 ,`city` VARCHAR(255) NOT NULL
 ,`state` CHAR(2) NOT NULL
 ,`zipcode` VARCHAR(9) NOT NULL
);

CREATE TABLE `demo`.`user` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY
 ,`name` VARCHAR(255) NOT NULL
 ,`address_id` INT NOT NULL
 ,FOREIGN KEY `address` (`address_id`) REFERENCES `demo`.`address` (`id`)
);
