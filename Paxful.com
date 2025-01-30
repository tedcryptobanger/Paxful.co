require('dotenv').config();
const express = require('express');
const session = require('express-session');
const passport = require('passport');
const GitHubStrategy = require('passport-github2').Strategy;

const app = express();

// Session setup
app.use(session({ secret: process.env.SESSION_SECRET, resave: false, saveUninitialized: false }));

// Passport setup
app.use(passport.initialize());
app.use(passport.session());

passport.use(new GitHubStrategy({
    clientID: process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
    callbackURL: "http://localhost:3000/auth/github/callback"
}, (accessToken, refreshToken, profile, done) => {
    return done(null, profile);
}));

passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((obj, done) => done(null, obj));

// Routes
app.get('/', (req, res) => {
    res.send('<h1>GitHub Login</h1><a href="/auth/github">Login with GitHub</a>');
});

app.get('/auth/github', passport.authenticate('github', { scope: ['user:email'] }));

app.get('/auth/github/callback', passport.authenticate('github', { failureRedirect: '/' }), (req, res) => {
    res.redirect('/dashboard');
});

app.get('/dashboard', (req, res) => {
    if (!req.isAuthenticated()) return res.redirect('/');
    res.send(`<h1>Welcome ${req.user.displayName}</h1><a href="/logout">Logout</a>`);
});

app.get('/logout', (req, res) => {
    req.logout(() => res.redirect('/'));
});

// Start server
app.listen(3000, () => console.log('Server running on http://localhost:3000'));
