<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the
 * installation. You don't have to use the web site, you can
 * copy this file to "wp-config.php" and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * MySQL settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://codex.wordpress.org/Editing_wp-config.php
 *
 * @package WordPress
 */

// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define('DB_NAME', '[DBNAME]');

/** MySQL database username */
define('DB_USER', '[USER]');

/** MySQL database password */
define('DB_PASSWORD', '[PASS]');

/** MySQL hostname */
define('DB_HOST', '[HOST]');

/** Database Charset to use in creating database tables. */
define('DB_CHARSET', 'utf8mb4');

/** The Database Collate type. Don't change this if in doubt. */
define('DB_COLLATE', '');

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         'Nvl@E@w<X1!@rT^Aqa [}Mf#fd$H`oJz`0L*^+4CBB*/|>efg( !p]j_Nd&cFz^Q');
define('SECURE_AUTH_KEY',  '~dh/6wUbTBhZ)(6?!5h)TY>,E>//NHE(C(3Eg*ToSfl+]t`={p,dC.ms.I+T?35o');
define('LOGGED_IN_KEY',    '9TSS3X#NyLw/EoN@j]@Q@=]W3p W>c,ADW?ZdCxk=+xfstGLV2!7,cG(A@yeMRn/');
define('NONCE_KEY',        'QBqDS[$]C&*B<ul$I *)PTRYzMuvbZF{|AKi:*IK NsPw[pXpURnzm~q>%1l8&R^');
define('AUTH_SALT',        'e3uz:V{.(hLG:WbI!dZ^)[;fPB]?ot`Q/[zNUe/yY<39YOhiS&!+^e]$NN=TlZ:9');
define('SECURE_AUTH_SALT', '*r)+Gfh}xNP9kAIICr^a1,/uK}?K1M,K.{g,l_my}XK;kbAP`?Ak:Vdz27+7m,G@');
define('LOGGED_IN_SALT',   '50KXj3uYEW+OK(:f^RJ;;.cZ!+MpN!YA.R8Voij,dmXl+M#XM*|FY[lN_9(YE{={');
define('NONCE_SALT',       '#EC:2bMjJ3h9$|sCrQ;{Aj8[6(0290}KyU%@5!9I6L8&;t7 hiD,IySmnk>v@dIg');

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix  = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the Codex.
 *
 * @link https://codex.wordpress.org/Debugging_in_WordPress
 */
define('WP_DEBUG', false);

/* That's all, stop editing! Happy blogging. */

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
