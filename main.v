module main

import vweb
import pg
import json
import rand
import rand.util

const (
	port = 8090
)

struct ModsRepo {
	db pg.DB
}

struct App {
pub mut:
	vweb      vweb.Context // TODO embed
	db        pg.DB
	cur_user  User
	mods_repo ModsRepo
}

fn main() {
	seed := util.time_seed_array(2)
	rand.seed([seed[0], seed[1]])
	vweb.run<App>(port)
}

pub fn (mut app App) init_once() {
	println('pg.connect()')
	db := pg.connect(pg.Config{
		host: 'localhost'
		dbname: 'vpm'
		user: 'admin'
	}) or {
		panic(err)
	}
	app.db = db
	app.cur_user = User{}
	app.mods_repo = ModsRepo{app.db}
	// app.vweb.serve_static('/img/github.png', 'img/github.png')
}

pub fn (mut app App) init() {
}

pub fn (mut app App) index() {
	app.vweb.set_cookie({
		name: 'vpm'
		value: '777'
	})
	mods := app.find_all_mods()
	println(123) // TODO remove, won't work without it
	$vweb.html()
}

pub fn (mut app App) reset() {
}

pub fn (mut app App) new() {
	app.auth()
	logged_in := app.cur_user.name != ''
	println('new() loggedin: $logged_in')
	println(123) // TODO remove, won't work without it
	$vweb.html()
}

const (
	max_name_len = 10
)

fn is_valid_mod_name(s string) bool {
	if s.len > max_name_len || s.len < 2 {
		return false
	}
	for c in s {
		// println(c.str())
		if !(c >= `A` && c <= `Z`) && !(c >= `a` && c <= `z`) && !(c >= `0` && c <= `9`) && c != `.` {
			return false
		}
	}
	return true
}

// [post]
pub fn (mut app App) create_module() {
	app.auth()
	name := app.vweb.form['name'].to_lower()
	println('CREATE name="$name"')
	if app.cur_user.name == '' || !is_valid_mod_name(name) {
		println('not valid mod name curuser="$app.cur_user.name"')
		app.vweb.redirect('/')
		return
	}
	url := app.vweb.form['url'].replace('<', '&lt;')
	println('CREATE url="$url"')
	if !url.starts_with('github.com/') && !url.starts_with('http://github.com/') && !url.starts_with('https://github.com/') {
		println('NOT GITHUB')
		app.vweb.redirect('/')
		return
	}
	println('CREATE url="$url"')
	mut vcs := app.vweb.form['vcs'].to_lower()
	if vcs == '' {
		vcs = 'git'
	}
	if vcs !in supported_vcs_systems {
		println('Unsupported vcs: $vcs')
		app.vweb.redirect('/')
		return
	}
	app.mods_repo.insert_module(app.cur_user.name + '.' + name.limit(max_name_len), url.limit(50),
		vcs.limit(3))
	app.vweb.redirect('/')
}

pub fn (mut app App) mod() {
	name := app.get_mod_name()
	println('mod name=$name')
	mod := app.mods_repo.retrieve(name) or {
		app.vweb.redirect('/')
		return
	}
	// comments := app.find_comments(id)
	// show_form := true
	$vweb.html()
}

pub fn (mut app App) jsmod() {
	name := app.vweb.req.url.replace('jsmod/', '')[1..]
	println('MOD name=$name')
	app.mods_repo.inc_nr_downloads(name)
	mod := app.mods_repo.retrieve(name) or {
		app.vweb.json('404')
		return
	}
	app.vweb.json(json.encode(mod))
}

// "/post/:id/:title"
pub fn (app App) get_mod_name() string {
	return app.vweb.req.url[5..]
}
