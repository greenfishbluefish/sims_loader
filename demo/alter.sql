CREATE TABLE IF NOT EXISTS `demo`.`group` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY
 ,`name` VARCHAR(255) NOT NULL UNIQUE
);

INSERT INTO `demo`.`group` (`id`, `name`) VALUES (1, 'Demo');

ALTER TABLE `demo`.`user`
  ADD COLUMN `group_id` INT NOT NULL DEFAULT 1;

ALTER TABLE `demo`.`user`
  MODIFY COLUMN `group_id` INT NOT NULL
 ,ADD FOREIGN KEY `group` (`group_id`) REFERENCES `demo`.`group` (`id`);
