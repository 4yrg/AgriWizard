package main

import (
	"bytes"
	"fmt"
	"text/template"
)

// TemplateEngine resolves a template_id to rendered subject + body.
type TemplateEngine struct {
	store *Store
}

func NewTemplateEngine(store *Store) *TemplateEngine {
	return &TemplateEngine{store: store}
}

// Render loads a template from the database, executes it with the provided
// variables, and returns the rendered subject and body.
// Template syntax is standard Go text/template: {{.variable_name}}
func (te *TemplateEngine) Render(templateID string, variables map[string]string) (subject, body string, err error) {
	tmpl, err := te.store.GetTemplate(templateID)
	if err != nil {
		return "", "", fmt.Errorf("template %q not found: %w", templateID, err)
	}

	subject, err = renderOne("subject", tmpl.SubjectTemplate, variables)
	if err != nil {
		return "", "", fmt.Errorf("render subject: %w", err)
	}

	body, err = renderOne("body", tmpl.BodyTemplate, variables)
	if err != nil {
		return "", "", fmt.Errorf("render body: %w", err)
	}

	return subject, body, nil
}

func renderOne(name, text string, data map[string]string) (string, error) {
	t, err := template.New(name).Option("missingkey=zero").Parse(text)
	if err != nil {
		return "", err
	}
	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return "", err
	}
	return buf.String(), nil
}
