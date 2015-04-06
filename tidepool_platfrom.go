package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"time"
)

const (
	TP_SESSION_TOKEN = "x-tidepool-session-token"
)

type (
	Tidepool struct {
		config     *TidepoolConfig
		httpClient *http.Client
		User       *User
	}
	TidepoolConfig struct {
		Auth   string `json:"auth"`
		Upload string `json:"upload"`
		Query  string `json:"query"`
	}
)

func NewTidepool(cfg *TidepoolConfig, usrName, pw string) *Tidepool {

	client := &Tidepool{config: cfg, httpClient: &http.Client{}, User: &User{Name: usrName, Pw: pw}}

	if err := client.Login(); err != nil {
		log.Panicf("Error init client: ", err)
		return nil
	}
	return client
}

func (tc *Tidepool) Ping() error {
	req, _ := http.NewRequest("GET", tc.config.Auth+"/status", nil)

	if resp, err := tc.httpClient.Do(req); err != nil {
		return errors.New("Issue with the tidepool platform: " + err.Error())
	} else if resp.StatusCode != http.StatusOK {
		return errors.New("Issue with the tidepool platform: " + string(resp.StatusCode))
	}
	return nil
}

// we need to login to the platform to be able to us it
func (tc *Tidepool) Login() (err error) {

	req, err := http.NewRequest("POST", tc.config.Auth+"/login", nil)
	req.SetBasicAuth(tc.User.Name, tc.User.Pw)
	if resp, err := tc.httpClient.Do(req); err != nil {
		return err
	} else {
		if resp.StatusCode == http.StatusOK {
			tc.User.Token = resp.Header.Get(TP_SESSION_TOKEN)
			return nil
		}
		return errors.New("Issue logging in: " + string(resp.StatusCode))
	}
}

// we need to login to the platform to be able to us it
func (tc *Tidepool) Logout() (err error) {

	req, err := http.NewRequest("POST", tc.config.Auth+"/login", nil)
	req.SetBasicAuth(tc.User.Name, "") //tc.User.Pw)
	if resp, err := tc.httpClient.Do(req); err != nil {
		return err
	} else {
		if resp.StatusCode == http.StatusOK {
			tc.User.Token = resp.Header.Get(TP_SESSION_TOKEN)
			return nil
		}
		return errors.New("Issue logging in: " + string(resp.StatusCode))
	}
}

func (tc *Tidepool) Save(data []interface{}) error {

	jsonBlock, _ := json.Marshal(data)

	log.Println(" block to load ", bytes.NewBufferString(string(jsonBlock)))

	req, _ := http.NewRequest("POST", tc.config.Upload, bytes.NewBufferString(string(jsonBlock)))
	req.Header.Add(TP_SESSION_TOKEN, tc.User.Token)
	req.Header.Set("content-type", "application/json")

	if resp, err := tc.httpClient.Do(req); err != nil {
		log.Println("Error loading messages: ", err)
		return err
	} else {
		log.Printf("all good? [%d] [%s] ", resp.StatusCode, resp.Status)
		updatedToken := resp.Header.Get(TP_SESSION_TOKEN)
		if updatedToken != "" && tc.User.Token != updatedToken {
			tc.User.Token = updatedToken
			log.Println("updated the token")
		}
	}

	return nil
}

func (tc *Tidepool) Query(query string) ([]interface{}, error) {

	if qry.UserId == "" {
		qry.UserId = tc.User.Id
	}

	log.Println(" query to run ", query)

	req, _ := http.NewRequest("POST", tc.config.Upload, bytes.NewBufferString(query))
	req.Header.Add(TP_SESSION_TOKEN, tc.User.Token)
	req.Header.Set("content-type", "application/json")

	if resp, err := tc.httpClient.Do(req); err != nil {
		log.Println("Error running query: ", err)
		return nil, err
	} else {
		log.Printf("all good? [%d] [%s] ", resp.StatusCode, resp.Status)
		updatedToken := resp.Header.Get(TP_SESSION_TOKEN)
		if updatedToken != "" && tc.User.Token != updatedToken {
			tc.User.Token = updatedToken
			log.Println("updated the token")
		}
	}

	return nil, nil
}

func setServer(server string) TidepoolConfig {
	const (
		local   = "http://localhost:8009"
		devel   = "https://devel-api.tidepool.io"
		staging = "https://staging-api.tidepool.io"
		prod    = "https://api.tidepool.io"
		auth    = "/auth"
		query   = "/query"
		upload  = "/data"
	)
	log.Print("set server to " + server)

	if server == "devel" {
		return TidepoolConfig{Auth: devel + auth, Upload: devel + upload, Query: devel + query}
	} else if server == "staging" {
		return TidepoolConfig{Auth: staging + auth, Upload: staging + upload, Query: staging + query}
	} else if server == "prod" {
		return TidepoolConfig{Auth: prod + auth, Upload: prod + upload, Query: prod + query}
	}
	//defaults to local
	return TidepoolConfig{Auth: local + auth, Upload: local + upload, Query: local + query}
}

func main() {

	server := flag.String("setserver", "local", "setserver: can be local, devel, staging, or prod")
	login := flag.String("login", "", "login email@addr.com")
	query := flag.String("query", "", "query types e.g. smbg, cbg, bolus, basal")

	envConfig := setServer(*server)

}
